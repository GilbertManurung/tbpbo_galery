const mongoose = require("mongoose");

const PinSchema = new mongoose.Schema(
  {
    title: String,
    description: String,
    category: String,
    tags: String,
    imagePath: String, // Local path or URL
  },
  { timestamps: true }
);

module.exports = mongoose.model("Pin", PinSchema);
