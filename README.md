# TTD Darshan & Donation Booking System

A web-based application that enables devotees to book TTD darshan tickets and make donations online. The system provides secure user authentication, darshan slot booking, donation management, booking history, and administrative controls for efficient temple service management.

## Features

### User Module
- User Registration and Login
- Secure Authentication
- View Available Darshan Slots
- Book Darshan Tickets
- Book Available Rooms
- Make Donations
- View Booking History
- Profile Management

### Admin Module
- Admin Login
- Manage Darshan Slots
- Manage Donations
- View User Bookings
- User Management
- Dashboard and Reports

## Technology Stack

### Frontend
- HTML
- CSS
- JavaScript

### Backend
- Python (Flask)

### Database
- MySQL

## Installation

### 1. Clone the Repository

```bash
git clone https://github.com/Saranya-T3/TTD-Darshan-Booking.git
cd TTD-Darshan-Booking
```

### 2. Create a Virtual Environment

```bash
python -m venv venv
```

Activate the virtual environment:

**Windows**
```bash
venv\Scripts\activate
```

**Linux/Mac**
```bash
source venv/bin/activate
```

### 3. Install Dependencies

```bash
pip install -r requirements.txt
```

### 4. Configure the Database

Create a MySQL database and import the provided SQL file:

```sql
ttd_final.sql
```

Update the database configuration in the project:

```python
DB_HOST = "localhost"
DB_USER = "root"
DB_PASSWORD = "your_password"
DB_NAME = "your_database_name"
```

### 5. Run the Application

```bash
python app.py
```

Open the application in your browser:

```
http://localhost:5000
```

## Database

The application uses MySQL to store:

- User Information
- Darshan Bookings
- Room Bookings
- Donation Records
- Admin Details
- Slot Availability Data
