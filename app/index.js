const express = require('express');

const app = express();
const PORT = process.env.PORT || 3000;

app.get('/', (_req, res) => {
  res.send(`
    <!DOCTYPE html>
    <html>
      <head><title>Cloud &amp; DevOps Final Project</title></head>
      <body>
        <h1>Hello from Abdalhakim Elghweiry</h1>
        <p>Cloud Computing &amp; DevOps Final Project</p>
      </body>
    </html>
  `);
});

app.get('/health', (_req, res) => {
  res.status(200).json({ status: 'ok' });
});

app.listen(PORT, () => {
  console.log(`Server listening on port ${PORT}`);
});
