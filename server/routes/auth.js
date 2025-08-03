const express = require("express");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const User = require("../models/User");

const router = express.Router();

// Gunakan variabel lingkungan untuk keamanan
const JWT_SECRET = process.env.JWT_SECRET || "your_default_secret";

// ======================
// ✅ REGISTER
// ======================
router.post("/register", async (req, res) => {
  const { name, email, password } = req.body;

  // Validasi field
  if (!name || !email || !password) {
    return res.status(400).json({ msg: "Semua field wajib diisi" });
  }

  try {
    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(400).json({ msg: "User sudah terdaftar" });
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    const newUser = new User({ name, email, password: hashedPassword });
    await newUser.save();

    return res.status(201).json({ msg: "User berhasil dibuat" });
  } catch (err) {
    console.error("Register error:", err.message);
    return res.status(500).json({ error: "Terjadi kesalahan server" });
  }
});

// ======================
// ✅ LOGIN
// ======================
router.post("/login", async (req, res) => {
  const { email, password } = req.body;

  // Validasi input
  if (!email || !password) {
    return res.status(400).json({ msg: "Email dan password wajib diisi" });
  }

  try {
    const user = await User.findOne({ email });
    if (!user) {
      return res.status(400).json({ msg: "Email atau password salah" });
    }

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(400).json({ msg: "Email atau password salah" });
    }

    // Buat token
    const token = jwt.sign({ id: user._id }, JWT_SECRET, {
      expiresIn: "1h",
    });

    return res.status(200).json({
      token,
      userId: user._id,
      name: user.name,
      email: user.email,
    });
  } catch (err) {
    console.error("Login error:", err.message);
    return res.status(500).json({ error: "Terjadi kesalahan server" });
  }
});

module.exports = router;
