const nodemailer = require("nodemailer");

const transporter = nodemailer.createTransport({
  host: "smtp.gmail.com",
  port: 587,
  secure: false, // true for 465, false for other ports
  auth: {
    user: "stepify.app@gmail.com",
    pass: "tycb dfdx hdho czua",
  },
});

console.log("Testing connection...");
transporter.verify(function (error, success) {
  if (error) {
    console.log("Connection error:", error);
  } else {
    console.log("Server is ready to take our messages");
  }
});
