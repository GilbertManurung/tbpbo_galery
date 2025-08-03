const express = require("express");
const mongoose = require("mongoose");
const cors = require("cors");
const bodyParser = require("body-parser");
const path = require("path");
const os = require("os");
require("dotenv").config();

const authRoutes = require("./routes/auth");
const galleryRoutes = require("./routes/gallery_routes");

// 🔍 Cari IP lokal otomatis (supaya HP di jaringan sama bisa akses)
function getLocalIp() {
  const interfaces = os.networkInterfaces();
  for (let name in interfaces) {
    for (let iface of interfaces[name]) {
      if (iface.family === "IPv4" && !iface.internal) {
        return iface.address;
      }
    }
  }
  return "127.0.0.1"; // fallback jika gagal
}

const LOCAL_IP = getLocalIp();
const app = express();
const PORT = process.env.PORT || 5000;
const HOST = "0.0.0.0"; // agar bisa diakses dari HP
const MONGO_URI =
  process.env.MONGO_URI || "mongodb://127.0.0.1:27017/gallery_app";

// 📌 Middleware
app.use(cors());
app.use(bodyParser.json());

// ✅ Serve folder uploads secara statis
// Gunakan path absolute untuk menghindari masalah
app.use("/uploads", express.static(path.join(__dirname, "uploads")));

// 📌 Routes
app.use("/api/auth", authRoutes);
app.use("/api/gallery", galleryRoutes(LOCAL_IP)); // kirim IP ke routes

// 📌 Test route
app.get("/", (req, res) => {
  res.send("🎉 Gallery API is running properly!");
});

// 📌 Connect ke MongoDB & Jalankan Server
mongoose
  .connect(MONGO_URI)
  .then(() => {
    console.log("✅ MongoDB Connected");
    app.listen(PORT, HOST, () => {
      console.log(`🚀 Server running at:  http://${LOCAL_IP}:${PORT}`);
      console.log(
        `📂 Static files served at: http://${LOCAL_IP}:${PORT}/uploads`
      );
    });
  })
  .catch((err) => {
    console.error("❌ MongoDB connection error:", err.message);
    process.exit(1);
  });
