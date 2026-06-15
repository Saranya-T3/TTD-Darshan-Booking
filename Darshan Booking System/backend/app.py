"""
TTD — Tirumala Tirupati Devasthanams
Python / Flask Backend  |  app.py
Run:  python app.py
"""

import random
import string
import time
from pathlib import Path
from datetime import datetime, timedelta, date
from functools import wraps

import bcrypt
import jwt
import mysql.connector
from flask import Flask, jsonify, request
from flask_cors import CORS

# ============================================================
#  CONFIG  — edit these values to match your MySQL setup
# ============================================================
DB_HOST     = "localhost"
DB_USER     = "root"
DB_PASSWORD = "2007"          # ← change this
DB_NAME     = "ttd"
JWT_SECRET  = "ttd_super_secret_key_change_in_production"
JWT_DAYS    = 7
PORT        = 5000
# ============================================================

FRONTEND_DIR = (Path(__file__).resolve().parent.parent / "frontend").resolve()

app = Flask(__name__, static_folder=str(FRONTEND_DIR), static_url_path="")
CORS(app)


# ── DB connection helper ────────────────────────────────────
def get_db():
    return mysql.connector.connect(
        host="localhost", user="root",
        password="$araT373.5271932.T", database="ttd"
    )


def query(sql, params=None, fetch="all", commit=False):
    """Run a query and return rows / lastrowid."""
    conn = get_db()
    cur  = conn.cursor(dictionary=True)
    cur.execute(sql, params or ())
    if commit:
        conn.commit()
        result = cur.lastrowid
    elif fetch == "one":
        result = cur.fetchone()
    else:
        result = cur.fetchall()
    cur.close()
    conn.close()
    return result


# ── JWT helpers ─────────────────────────────────────────────
def make_token(payload: dict) -> str:
    payload["exp"] = datetime.utcnow() + timedelta(days=JWT_DAYS)
    return jwt.encode(payload, JWT_SECRET, algorithm="HS256")


def decode_token(token: str) -> dict | None:
    try:
        return jwt.decode(token, JWT_SECRET, algorithms=["HS256"])
    except jwt.PyJWTError:
        return None


def auth_required(f):
    """Decorator — protects routes that need a valid JWT."""
    @wraps(f)
    def wrapper(*args, **kwargs):
        header = request.headers.get("Authorization", "")
        token  = header.replace("Bearer ", "").strip()
        if not token:
            return jsonify(success=False, message="No token provided. Please login."), 401
        user = decode_token(token)
        if not user:
            return jsonify(success=False, message="Invalid or expired token. Please login."), 403
        request.user = user
        return f(*args, **kwargs)
    return wrapper


# ── Misc helpers ─────────────────────────────────────────────
def gen_ref(length=8) -> str:
    chars = string.ascii_uppercase + string.digits
    return "TTD" + "".join(random.choices(chars, k=length))


def gen_txn() -> str:
    rnd = "".join(random.choices(string.ascii_uppercase + string.digits, k=5))
    return f"TTD{int(time.time())}{rnd}"


def ok(data: dict = None, **kwargs):
    return jsonify(success=True, **(data or {}), **kwargs)


def err(msg: str, code: int = 400):
    return jsonify(success=False, message=msg), code


# ============================================================
#  AUTH ROUTES
# ============================================================

@app.route("/api/auth/register", methods=["POST"])
def register():
    d = request.json or {}
    name      = (d.get("name") or "").strip()
    email     = (d.get("email") or "").strip().lower()
    phone     = (d.get("phone_number") or "").strip()
    country   = (d.get("country") or "India").strip()
    aadhar    = (d.get("aadhar_number") or "").strip() or None
    passport  = (d.get("passport_number") or "").strip().upper() or None
    password  = d.get("password") or ""

    if not all([name, email, phone, password]):
        return err("Name, email, phone and password are required.")
    if not aadhar and not passport:
        return err("Aadhar number or Passport number is required.")
    if aadhar and len(aadhar) != 12:
        return err("Aadhar number must be exactly 12 digits.")
    if aadhar and not aadhar.isdigit():
        return err("Aadhar number must contain only digits.")
    if len(password) < 6:
        return err("Password must be at least 6 characters.")

    # Check duplicate email
    existing = query("SELECT user_id FROM USERS WHERE email=%s", (email,), fetch="one")
    if existing:
        return err("Email is already registered.", 409)

    hashed = bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()
    try:
        uid = query(
            """INSERT INTO USERS (name,email,phone_number,aadhar_number,passport_number,country,password)
               VALUES (%s,%s,%s,%s,%s,%s,%s)""",
            (name, email, phone, aadhar, passport, country, hashed),
            commit=True
        )
        return ok(message="Registration successful! Please login.", user_id=uid), 201
    except mysql.connector.IntegrityError as e:
        if "Duplicate" in str(e):
            return err("Aadhar or Passport number already registered.", 409)
        return err(str(e))
    except Exception as e:
        return err(str(e))


@app.route("/api/auth/login", methods=["POST"])
def login():
    d        = request.json or {}
    email    = (d.get("email") or "").strip().lower()
    password = d.get("password") or ""

    if not email or not password:
        return err("Email and password are required.")

    user = query(
        "SELECT * FROM USERS WHERE email=%s AND user_status='active'",
        (email,), fetch="one"
    )
    if not user:
        return err("Invalid email or password.", 401)

    if not bcrypt.checkpw(password.encode(), user["password"].encode()):
        return err("Invalid email or password.", 401)

    token = make_token({
        "user_id": user["user_id"],
        "email":   user["email"],
        "name":    user["name"]
    })
    return ok(
        message="Login successful.",
        token=token,
        user={
            "user_id":      user["user_id"],
            "name":         user["name"],
            "email":        user["email"],
            "phone_number": user["phone_number"],
            "country":      user["country"]
        }
    )


@app.route("/api/auth/profile", methods=["GET"])
@auth_required
def profile():
    user = query(
        """SELECT user_id,name,email,phone_number,aadhar_number,
                  passport_number,country,created_at,user_status
           FROM USERS WHERE user_id=%s""",
        (request.user["user_id"],), fetch="one"
    )
    if not user:
        return err("User not found.", 404)
    # Convert datetime to string for JSON
    if user.get("created_at"):
        user["created_at"] = str(user["created_at"])
    return ok(user=user)


# ============================================================
#  DARSHAN TYPES
# ============================================================

@app.route("/api/darshan-types", methods=["GET"])
def darshan_types():
    rows = query("SELECT * FROM DARSHAN_TYPE ORDER BY price")
    return ok(types=rows)


# ============================================================
#  TIME SLOTS
# ============================================================

@app.route("/api/timeslots", methods=["GET"])
def timeslots():
    d_date   = request.args.get("date")
    type_id  = request.args.get("darshan_type_id")
    stype    = request.args.get("slot_type")

    sql    = "SELECT * FROM vw_slot_availability WHERE 1=1"
    params = []
    if d_date:  sql += " AND darshan_date=%s";      params.append(d_date)
    if type_id: sql += " AND darshan_type_id=%s";   params.append(type_id)
    if stype:   sql += " AND slot_type=%s";          params.append(stype)
    sql += " ORDER BY darshan_date, start_time"

    rows = query(sql, params)
    # Serialize date/time
    for r in rows:
        if r.get("darshan_date"):
            r["darshan_date"]  = str(r["darshan_date"])
        if r.get("start_time") is not None:
            r["start_time"] = str(r["start_time"])
        if r.get("end_time") is not None:
            r["end_time"]   = str(r["end_time"])
        if r.get("price") is not None:
            r["price"] = float(r["price"])
    return ok(slots=rows)


@app.route("/api/timeslots/dates", methods=["GET"])
def timeslot_dates():
    rows = query(
        """SELECT DISTINCT darshan_date FROM TIME_SLOT
           WHERE darshan_date >= CURDATE()
           ORDER BY darshan_date LIMIT 60"""
    )
    dates = [str(r["darshan_date"]) for r in rows]
    return ok(dates=dates)


# ============================================================
#  DARSHAN BOOKINGS
# ============================================================

@app.route("/api/bookings/darshan", methods=["POST"])
@auth_required
def create_darshan_booking():
    d          = request.json or {}
    slot_id    = d.get("time_slot_id")
    n_persons  = d.get("number_of_persons")
    btype      = d.get("booking_type")
    pilgrims   = d.get("pilgrims", [])
    user_id    = request.user["user_id"]

    if not all([slot_id, n_persons, btype, pilgrims]):
        return err("All booking fields are required.")
    if not isinstance(pilgrims, list) or len(pilgrims) != int(n_persons):
        return err(f"Pilgrim details count must match number_of_persons ({n_persons}).")

    conn = get_db()
    cur  = conn.cursor(dictionary=True)
    try:
        # Check slot capacity
        cur.execute("SELECT * FROM TIME_SLOT WHERE time_slot_id=%s", (slot_id,))
        slot = cur.fetchone()
        if not slot:
            return err("Time slot not found.")
        available = slot["max_capacity"] - slot["booked_count"]
        if available < int(n_persons):
            return err(f"Only {available} seat(s) available in this slot.")

        # Generate unique booking reference
        while True:
            ref = gen_ref()
            cur.execute("SELECT booking_id FROM DARSHAN_BOOKING WHERE booking_reference=%s", (ref,))
            if not cur.fetchone():
                break

        cur.execute(
            """INSERT INTO DARSHAN_BOOKING
               (booking_reference,user_id,time_slot_id,number_of_persons,booking_type,booking_status)
               VALUES (%s,%s,%s,%s,%s,'pending')""",
            (ref, user_id, slot_id, n_persons, btype)
        )
        booking_id = cur.lastrowid

        # Insert pilgrims
        for p in pilgrims:
            if not all([p.get("pilgrim_name"), p.get("age"), p.get("gender")]):
                raise ValueError("Pilgrim name, age and gender are required.")
            if not p.get("aadhar_number") and not p.get("passport_number"):
                raise ValueError("Each pilgrim needs Aadhar or Passport number.")
            aadhar = (p.get("aadhar_number") or "").strip() or None
            if aadhar and len(aadhar) != 12:
                raise ValueError("Pilgrim Aadhar must be 12 digits.")
            cur.execute(
                """INSERT INTO PILGRIM_DETAILS
                   (booking_id,pilgrim_name,age,gender,aadhar_number,passport_number,country)
                   VALUES (%s,%s,%s,%s,%s,%s,%s)""",
                (booking_id, p["pilgrim_name"], p["age"], p["gender"],
                 aadhar,
                 (p.get("passport_number") or "").strip().upper() or None,
                 p.get("country", "India"))
            )
        conn.commit()

        # Get price for total
        cur.execute(
            """SELECT dt.price FROM DARSHAN_TYPE dt
               JOIN TIME_SLOT t ON dt.darshan_type_id=t.darshan_type_id
               WHERE t.time_slot_id=%s""", (slot_id,)
        )
        row   = cur.fetchone()
        price = float(row["price"]) if row else 0.0
        total = price * int(n_persons)

        return ok(
            message="Booking created. Please complete payment to confirm.",
            booking_id=booking_id,
            booking_reference=ref,
            total_amount=total
        ), 201

    except ValueError as ve:
        conn.rollback()
        return err(str(ve))
    except Exception as e:
        conn.rollback()
        return err(str(e))
    finally:
        cur.close()
        conn.close()


@app.route("/api/bookings/darshan", methods=["GET"])
@auth_required
def list_darshan_bookings():
    rows = query(
        """SELECT vb.*, p.payment_status, p.transaction_id, p.payment_method
           FROM vw_user_bookings vb
           LEFT JOIN PAYMENT p ON p.booking_id = vb.booking_id
           WHERE vb.user_id=%s
           ORDER BY vb.created_at DESC""",
        (request.user["user_id"],)
    )
    for r in rows:
        for k in ("darshan_date","start_time","end_time","created_at"):
            if r.get(k) is not None: r[k] = str(r[k])
        if r.get("price") is not None:    r["price"]        = float(r["price"])
        if r.get("total_amount") is not None: r["total_amount"] = float(r["total_amount"])
    return ok(bookings=rows)


@app.route("/api/bookings/darshan/<int:bid>", methods=["GET"])
@auth_required
def get_darshan_booking(bid):
    booking = query(
        """SELECT vb.*, p.payment_status, p.transaction_id
           FROM vw_user_bookings vb
           LEFT JOIN PAYMENT p ON p.booking_id=vb.booking_id
           WHERE vb.booking_id=%s AND vb.user_id=%s""",
        (bid, request.user["user_id"]), fetch="one"
    )
    if not booking:
        return err("Booking not found.", 404)
    for k in ("darshan_date","start_time","end_time","created_at"):
        if booking.get(k) is not None: booking[k] = str(booking[k])
    pilgrims = query("SELECT * FROM PILGRIM_DETAILS WHERE booking_id=%s", (bid,))
    return ok(booking=booking, pilgrims=pilgrims)


@app.route("/api/bookings/darshan/<int:bid>/cancel", methods=["PUT"])
@auth_required
def cancel_darshan(bid):
    bk = query(
        "SELECT * FROM DARSHAN_BOOKING WHERE booking_id=%s AND user_id=%s",
        (bid, request.user["user_id"]), fetch="one"
    )
    if not bk:
        return err("Booking not found.", 404)
    if bk["booking_status"] == "cancelled":
        return err("Already cancelled.")
    query(
        "UPDATE DARSHAN_BOOKING SET booking_status='cancelled' WHERE booking_id=%s",
        (bid,), commit=True
    )
    return ok(message="Booking cancelled successfully.")


# ============================================================
#  ROOM BOOKINGS
# ============================================================

@app.route("/api/bookings/room", methods=["POST"])
@auth_required
def create_room_booking():
    d       = request.json or {}
    room_id = d.get("room_id")
    cin     = d.get("check_in_date")
    cout    = d.get("check_out_date")
    bk_id   = d.get("booking_id") or None
    user_id = request.user["user_id"]

    if not all([room_id, cin, cout]):
        return err("Room, check-in and check-out dates are required.")

    cin_d  = datetime.strptime(cin,  "%Y-%m-%d").date()
    cout_d = datetime.strptime(cout, "%Y-%m-%d").date()
    if cout_d <= cin_d:
        return err("Check-out must be after check-in.")

    room = query("SELECT * FROM ACCOMMODATION WHERE room_id=%s", (room_id,), fetch="one")
    if not room:
        return err("Room not found.", 404)

    # Check conflicts
    conflicts = query(
        """SELECT room_booking_id FROM ROOM_BOOKING
           WHERE room_id=%s AND booking_status!='cancelled'
             AND NOT (check_out_date<=%s OR check_in_date>=%s)""",
        (room_id, cin, cout)
    )
    if conflicts:
        return err("Room is not available for selected dates.")

    nights = (cout_d - cin_d).days
    total  = float(room["price_per_day"]) * nights

    rb_id = query(
        """INSERT INTO ROOM_BOOKING
           (booking_id,user_id,room_id,check_in_date,check_out_date,booking_status)
           VALUES (%s,%s,%s,%s,%s,'pending')""",
        (bk_id, user_id, room_id, cin, cout), commit=True
    )
    return ok(
        message="Room booking created. Please complete payment.",
        room_booking_id=rb_id, nights=nights, total_amount=total
    ), 201


@app.route("/api/bookings/room", methods=["GET"])
@auth_required
def list_room_bookings():
    rows = query(
        """SELECT rb.*, a.room_type, a.capacity, a.price_per_day,
                  p.payment_status, p.transaction_id,
                  DATEDIFF(rb.check_out_date, rb.check_in_date) AS nights,
                  (DATEDIFF(rb.check_out_date, rb.check_in_date)*a.price_per_day) AS total_amount
           FROM ROOM_BOOKING rb
           JOIN ACCOMMODATION a ON rb.room_id=a.room_id
           LEFT JOIN PAYMENT p ON p.room_booking_id=rb.room_booking_id
           WHERE rb.user_id=%s ORDER BY rb.created_at DESC""",
        (request.user["user_id"],)
    )
    for r in rows:
        for k in ("check_in_date","check_out_date","created_at"):
            if r.get(k) is not None: r[k] = str(r[k])
        if r.get("price_per_day") is not None: r["price_per_day"] = float(r["price_per_day"])
        if r.get("total_amount")  is not None: r["total_amount"]  = float(r["total_amount"])
    return ok(bookings=rows)


@app.route("/api/bookings/room/<int:rid>/cancel", methods=["PUT"])
@auth_required
def cancel_room(rid):
    rb = query(
        "SELECT * FROM ROOM_BOOKING WHERE room_booking_id=%s AND user_id=%s",
        (rid, request.user["user_id"]), fetch="one"
    )
    if not rb:
        return err("Room booking not found.", 404)
    if rb["booking_status"] == "cancelled":
        return err("Already cancelled.")
    query(
        "UPDATE ROOM_BOOKING SET booking_status='cancelled' WHERE room_booking_id=%s",
        (rid,), commit=True
    )
    return ok(message="Room booking cancelled.")


# ============================================================
#  ACCOMMODATION
# ============================================================

@app.route("/api/accommodation", methods=["GET"])
def list_rooms():
    cin  = request.args.get("checkin")
    cout = request.args.get("checkout")

    if cin and cout:
        rooms = query(
            """SELECT a.*,
                      CASE WHEN rb.room_id IS NOT NULL THEN 0 ELSE 1 END AS is_available
               FROM ACCOMMODATION a
               LEFT JOIN ROOM_BOOKING rb
                 ON rb.room_id=a.room_id
                 AND rb.booking_status!='cancelled'
                 AND NOT (rb.check_out_date<=%s OR rb.check_in_date>=%s)
               GROUP BY a.room_id
               ORDER BY a.price_per_day""",
            (cin, cout)
        )
    else:
        rooms = query(
            "SELECT *, 1 AS is_available FROM ACCOMMODATION ORDER BY price_per_day"
        )
    for r in rooms:
        if r.get("price_per_day") is not None: r["price_per_day"] = float(r["price_per_day"])
    return ok(rooms=rooms)


@app.route("/api/accommodation/<int:rid>", methods=["GET"])
def get_room(rid):
    room = query("SELECT * FROM ACCOMMODATION WHERE room_id=%s", (rid,), fetch="one")
    if not room:
        return err("Room not found.", 404)
    if room.get("price_per_day") is not None: room["price_per_day"] = float(room["price_per_day"])
    return ok(room=room)


# ============================================================
#  PAYMENT
# ============================================================

@app.route("/api/payment", methods=["POST"])
@auth_required
def process_payment():
    d              = request.json or {}
    booking_id     = d.get("booking_id")     or None
    room_booking_id= d.get("room_booking_id") or None
    amount         = d.get("amount")
    method         = d.get("payment_method")
    user_id        = request.user["user_id"]

    if not amount or not method:
        return err("Amount and payment method are required.")
    if not booking_id and not room_booking_id:
        return err("Provide a booking_id or room_booking_id.")

    conn = get_db()
    cur  = conn.cursor(dictionary=True)
    try:
        txn_id = gen_txn()
        cur.execute(
            """INSERT INTO PAYMENT
               (transaction_id,user_id,booking_id,room_booking_id,amount,payment_status,payment_method)
               VALUES (%s,%s,%s,%s,%s,'success',%s)""",
            (txn_id, user_id, booking_id, room_booking_id, amount, method)
        )
        if booking_id:
            cur.execute(
                "UPDATE DARSHAN_BOOKING SET booking_status='confirmed' WHERE booking_id=%s AND user_id=%s",
                (booking_id, user_id)
            )
        if room_booking_id:
            cur.execute(
                "UPDATE ROOM_BOOKING SET booking_status='confirmed' WHERE room_booking_id=%s AND user_id=%s",
                (room_booking_id, user_id)
            )
        conn.commit()
        return ok(message="Payment successful! Booking confirmed. 🙏", transaction_id=txn_id)
    except Exception as e:
        conn.rollback()
        return err(str(e))
    finally:
        cur.close()
        conn.close()


@app.route("/api/payment", methods=["GET"])
@auth_required
def payment_history():
    rows = query(
        """SELECT p.*,
                  db.booking_reference, dt.darshan_name, t.darshan_date,
                  rb.check_in_date, rb.check_out_date, a.room_type
           FROM PAYMENT p
           LEFT JOIN DARSHAN_BOOKING db ON p.booking_id      = db.booking_id
           LEFT JOIN TIME_SLOT t        ON db.time_slot_id   = t.time_slot_id
           LEFT JOIN DARSHAN_TYPE dt    ON t.darshan_type_id = dt.darshan_type_id
           LEFT JOIN ROOM_BOOKING rb    ON p.room_booking_id = rb.room_booking_id
           LEFT JOIN ACCOMMODATION a    ON rb.room_id        = a.room_id
           WHERE p.user_id=%s ORDER BY p.payment_date DESC""",
        (request.user["user_id"],)
    )
    for r in rows:
        for k in ("payment_date","darshan_date","check_in_date","check_out_date"):
            if r.get(k) is not None: r[k] = str(r[k])
        if r.get("amount") is not None: r["amount"] = float(r["amount"])
    return ok(payments=rows)


# ============================================================
#  DONATION
# ============================================================

@app.route("/api/donation", methods=["POST"])
@auth_required
def donate():
    d        = request.json or {}
    amount   = d.get("amount")
    don_type = d.get("donation_type") or "General"
    user_id  = request.user["user_id"]

    if not amount or float(amount) <= 0:
        return err("Please enter a valid donation amount.")

    did = query(
        "INSERT INTO DONATION (user_id,amount,donation_type) VALUES (%s,%s,%s)",
        (user_id, amount, don_type), commit=True
    )
    return ok(message="Thank you for your generous donation! 🙏", donation_id=did), 201


@app.route("/api/donation", methods=["GET"])
@auth_required
def donation_history():
    rows = query(
        "SELECT * FROM DONATION WHERE user_id=%s ORDER BY donation_date DESC",
        (request.user["user_id"],)
    )
    for r in rows:
        if r.get("donation_date") is not None: r["donation_date"] = str(r["donation_date"])
        if r.get("amount")        is not None: r["amount"]        = float(r["amount"])
    return ok(donations=rows)


# ── Health check ─────────────────────────────────────────────
@app.route("/api/health", methods=["GET"])
def api_health():
    return ok(message="TTD Python API running 🙏")


@app.route("/", methods=["GET"])
def health():
    return app.send_static_file("index.html")


# ── 404 ──────────────────────────────────────────────────────
@app.errorhandler(404)
def not_found(_):
    if not request.path.startswith("/api") and "." not in request.path:
        return app.send_static_file("index.html")
    return jsonify(success=False, message="Route not found"), 404


# ── Run ───────────────────────────────────────────────────────
if __name__ == "__main__":
    print(f"🚀  TTD Server → http://localhost:{PORT}")
    app.run(host="0.0.0.0", port=PORT, debug=True)
