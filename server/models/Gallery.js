const mongoose = require("mongoose");

const GallerySchema = new mongoose.Schema(
  {
    title: {
      type: String,
      required: [true, "Judul wajib diisi"],
      trim: true,
    },
    imageUrl: {
      type: String,
      required: [true, "Path gambar wajib diisi"],
    },
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: [true, "User ID wajib diisi"],
    },
  },
  {
    timestamps: true, // Menambahkan createdAt dan updatedAt secara otomatis
  }
);

module.exports = mongoose.model("Gallery", GallerySchema);
