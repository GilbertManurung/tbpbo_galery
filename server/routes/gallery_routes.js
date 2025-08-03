const express = require("express");
const multer = require("multer");
const path = require("path");
const fs = require("fs");
const Gallery = require("../models/Gallery");

module.exports = (LOCAL_IP) => {
  const router = express.Router();
  const PORT = process.env.PORT || 5000;
  const uploadDir = path.join(__dirname, "..", "uploads");

  // Ensure uploads directory exists
  if (!fs.existsSync(uploadDir)) {
    fs.mkdirSync(uploadDir, { recursive: true });
  }

  // 📦 Multer config
  const storage = multer.diskStorage({
    destination: (req, file, cb) => {
      cb(null, "uploads/");
    },
    filename: (req, file, cb) => {
      const timestamp = Date.now();
      const ext = path.extname(file.originalname);
      const filename = `${timestamp}${ext}`;
      cb(null, filename);
    },
  });

  const upload = multer({
    storage,
    limits: {
      fileSize: 10 * 1024 * 1024, // 10MB limit
    },
    fileFilter: (req, file, cb) => {
      const allowedTypes = /jpeg|jpg|png|gif|webp/;
      const extname = allowedTypes.test(
        path.extname(file.originalname).toLowerCase()
      );
      const mimetype = allowedTypes.test(file.mimetype);

      if (mimetype && extname) {
        return cb(null, true);
      } else {
        cb(new Error("Only image files are allowed!"));
      }
    },
  });

  /**
   * 📤 Upload gambar
   */
  router.post("/upload", upload.single("image"), async (req, res) => {
    try {
      console.log("Upload request received:", req.body);
      console.log("File info:", req.file);

      const { title, description, link, tag, category, userId } = req.body;

      if (!req.file) {
        return res.status(400).json({ error: "Gambar tidak ditemukan" });
      }

      if (!title || title.trim() === "") {
        // Delete uploaded file if validation fails
        if (req.file && req.file.path) {
          fs.unlinkSync(req.file.path);
        }
        return res.status(400).json({ error: "Judul wajib diisi" });
      }

      const imageUrl = `/uploads/${req.file.filename}`;
      const fullImageUrl = `http://${LOCAL_IP}:${PORT}${imageUrl}`;

      // Create new gallery item
      const newItem = new Gallery({
        title: title.trim(),
        description: description?.trim() || "",
        link: link?.trim() || "",
        tag: tag?.trim() || "",
        category: category?.trim() || "",
        userId: userId || null,
        imageUrl,
        createdAt: new Date(),
      });

      // Save to database
      const savedItem = await newItem.save();
      console.log("Item saved to database:", savedItem._id);

      // Return response with all data
      res.status(201).json({
        _id: savedItem._id,
        title: savedItem.title,
        description: savedItem.description,
        link: savedItem.link,
        tag: savedItem.tag,
        category: savedItem.category,
        userId: savedItem.userId,
        imageUrl: savedItem.imageUrl,
        fullImageUrl,
        createdAt: savedItem.createdAt,
      });
    } catch (err) {
      console.error("Upload error:", err);

      // Clean up uploaded file if database save fails
      if (req.file && req.file.path && fs.existsSync(req.file.path)) {
        try {
          fs.unlinkSync(req.file.path);
        } catch (deleteErr) {
          console.error("Error deleting file:", deleteErr);
        }
      }

      res.status(500).json({
        error: err.message || "Gagal upload gambar",
      });
    }
  });

  /**
   * 📥 Ambil semua gambar dari database dan folder uploads
   */
  router.get("/", async (req, res) => {
    try {
      console.log("Fetching gallery images...");

      // Get all items from database, sorted by newest first
      const dbItems = await Gallery.find().sort({ createdAt: -1, _id: -1 });
      console.log(`Found ${dbItems.length} items in database`);

      // Get all files from uploads directory
      const files = fs.existsSync(uploadDir) ? fs.readdirSync(uploadDir) : [];
      console.log(`Found ${files.length} files in uploads directory`);

      // Create response array prioritizing database entries
      const allItems = [];
      const processedFiles = new Set();

      // First, add all database items that have corresponding files
      for (const dbItem of dbItems) {
        if (dbItem.imageUrl) {
          const filename = dbItem.imageUrl.replace("/uploads/", "");
          const filePath = path.join(uploadDir, filename);

          if (fs.existsSync(filePath)) {
            processedFiles.add(filename);
            allItems.push({
              _id: dbItem._id,
              title: dbItem.title || "",
              description: dbItem.description || "",
              link: dbItem.link || "",
              tag: dbItem.tag || "",
              category: dbItem.category || "",
              userId: dbItem.userId || null,
              imageUrl: dbItem.imageUrl,
              fullImageUrl: `http://${LOCAL_IP}:${PORT}${dbItem.imageUrl}`,
              createdAt: dbItem.createdAt,
            });
          }
        }
      }

      // Then, add files that don't have database entries (orphaned files)
      for (const file of files) {
        if (
          !processedFiles.has(file) &&
          /\.(jpg|jpeg|png|gif|webp)$/i.test(file)
        ) {
          const imageUrl = `/uploads/${file}`;
          allItems.push({
            _id: file, // Use filename as temporary ID
            title: "",
            description: "",
            link: "",
            tag: "",
            category: "",
            userId: null,
            imageUrl,
            fullImageUrl: `http://${LOCAL_IP}:${PORT}${imageUrl}`,
            createdAt: null,
          });
        }
      }

      console.log(`Returning ${allItems.length} items total`);
      res.json(allItems);
    } catch (err) {
      console.error("Get error:", err);
      res.status(500).json({ error: err.message });
    }
  });

  /**
   * ❌ Hapus gambar
   */
  router.delete("/:id", async (req, res) => {
    try {
      console.log(`Deleting item with ID: ${req.params.id}`);

      const item = await Gallery.findById(req.params.id);

      if (!item) {
        return res.status(404).json({ error: "Item tidak ditemukan" });
      }

      // Delete file from filesystem
      if (item.imageUrl) {
        const filePath = path.join(
          __dirname,
          "..",
          item.imageUrl.startsWith("/") ? item.imageUrl.slice(1) : item.imageUrl
        );

        console.log(`Attempting to delete file: ${filePath}`);

        if (fs.existsSync(filePath)) {
          fs.unlinkSync(filePath);
          console.log(`File deleted successfully: ${filePath}`);
        } else {
          console.log(`File not found: ${filePath}`);
        }
      }

      // Delete from database
      await Gallery.findByIdAndDelete(req.params.id);
      console.log(`Database entry deleted: ${req.params.id}`);

      res.json({
        message: "Item berhasil dihapus",
        deletedId: req.params.id,
      });
    } catch (err) {
      console.error("Error deleting image:", err);
      res.status(500).json({ error: "Gagal menghapus item" });
    }
  });

  /**
   * 📄 Get single item by ID
   */
  router.get("/:id", async (req, res) => {
    try {
      const item = await Gallery.findById(req.params.id);

      if (!item) {
        return res.status(404).json({ error: "Item tidak ditemukan" });
      }

      const fullImageUrl = `http://${LOCAL_IP}:${PORT}${item.imageUrl}`;

      res.json({
        _id: item._id,
        title: item.title,
        description: item.description,
        link: item.link,
        tag: item.tag,
        category: item.category,
        userId: item.userId,
        imageUrl: item.imageUrl,
        fullImageUrl,
        createdAt: item.createdAt,
      });
    } catch (err) {
      console.error("Get single item error:", err);
      res.status(500).json({ error: err.message });
    }
  });

  return router;
};
