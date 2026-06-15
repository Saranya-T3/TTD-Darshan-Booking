/* nav.js – inject navbar HTML dynamically */
(function() {
  const nav = `
  <nav class="navbar">
    <div class="nav-inner">
      <a href="index.html" class="nav-brand">
        <span class="nav-logo">🛕</span>
        <div class="nav-name">TTD <small>Tirumala Tirupati Devasthanams</small></div>
      </a>
      <ul class="nav-links" id="navLinks">
        <li><a href="index.html">Home</a></li>
        <li><a href="darshan.html">Darshan</a></li>
        <li><a href="accommodation.html">Accommodation</a></li>
        <li><a href="donation.html">Donate</a></li>
        <li id="nl-dash" class="d-none"><a href="dashboard.html">My Bookings</a></li>
        <li id="nl-login"><a href="login.html" class="nav-cta">Login</a></li>
        <li id="nl-logout" class="d-none">
          <a href="#" class="nav-cta" style="background:#c0392b;color:white!important;" id="nl-logout-btn">
            Logout
          </a>
        </li>
      </ul>
      <div class="hamburger" id="hamburger"><span></span><span></span><span></span></div>
    </div>
  </nav>
  <div class="gold-bar"></div>`;

  document.getElementById('nav-placeholder').innerHTML = nav;
})();
