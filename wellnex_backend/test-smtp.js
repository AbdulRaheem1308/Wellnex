// Optional diagnostic only. Never commit credentials or run this automatically.
// The previously committed Gmail app password must be revoked independently.
async function verifySmtp(env = process.env, loadMailer = () => require("nodemailer")) {
  const user = env.SMTP_USER;
  const pass = env.SMTP_PASS;
  if (!user || !pass) {
    throw new Error("Set SMTP_USER and SMTP_PASS securely before running this diagnostic.");
  }
  const transporter = loadMailer().createTransport({
    host: "smtp.gmail.com", port: 587, secure: false, requireTLS: true,
    auth: { user, pass },
  });
  try { await transporter.verify(); } finally { transporter.close(); }
}
if (require.main === module) {
  verifySmtp().then(
    () => console.log("SMTP connection verified. No message was sent."),
    () => {
      console.error("SMTP verification failed. Check configuration privately.");
      process.exitCode = 1;
    },
  );
}
module.exports = { verifySmtp };
