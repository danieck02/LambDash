#!/bin/bash

echo "🚚 Transport Platform Installer (macOS)"
echo "========================================="

sleep 1

echo "📦 Controleren of Node.js geïnstalleerd is..."
if ! command -v node &> /dev/null
then
    echo "Node.js niet gevonden! Installeren via Homebrew..."
    brew install node
else
    echo "✔ Node.js OK"
fi

sleep 1

echo "📁 Project mappen aanmaken..."
mkdir -p transport-backend transport-dashboard

###############################################
# BACKEND
###############################################

echo "📦 Backend installeren..."
cd transport-backend

npm init -y >/dev/null

npm install express cors ws jsonwebtoken bcryptjs >/dev/null

echo "📄 Backend bestanden maken..."

# server.js
cat << 'EOF' > server.js
const express = require("express");
const cors = require("cors");
const http = require("http");

const app = express();
app.use(cors());
app.use(express.json());

app.use("/auth", require("./routes/auth"));
app.use("/orders", require("./routes/orders"));
app.use("/dashboard", require("./routes/dashboard"));

const server = http.createServer(app);
const { setupWebSocket } = require("./sockets");
setupWebSocket(server);

server.listen(3000, () =>
  console.log("🚀 Backend live op http://localhost:3000")
);
EOF

# sockets.js
cat << 'EOF' > sockets.js
let clients = [];

function setupWebSocket(server) {
  const WebSocket = require("ws");
  const wss = new WebSocket.Server({ server });

  wss.on("connection", (ws) => {
    clients.push(ws);
    ws.on("close", () => (clients = clients.filter(c => c !== ws)));
  });
}

function broadcast(data) {
  clients.forEach((client) => {
    try {
      client.send(JSON.stringify(data));
    } catch (err) {}
  });
}

module.exports = { setupWebSocket, broadcast };
EOF

mkdir -p routes middleware data

# authMiddleware.js
cat << 'EOF' > middleware/authMiddleware.js
const jwt = require("jsonwebtoken");
const SECRET = "supergeheim";

module.exports = function auth(roleRequired = null) {
  return (req, res, next) => {
    const token = req.headers.authorization?.split(" ")[1];
    if (!token) return res.status(401).json({ error: "Geen token" });

    try {
      const decoded = jwt.verify(token, SECRET);
      if (roleRequired && decoded.role !== roleRequired)
        return res.status(403).json({ error: "Geen toegang" });

      req.user = decoded;
      next();
    } catch (err) {
      res.status(401).json({ error: "Token ongeldig" });
    }
  };
};
EOF

# auth.js
cat << 'EOF' > routes/auth.js
const express = require("express");
const jwt = require("jsonwebtoken");
const bcrypt = require("bcryptjs");
const router = express.Router();
const users = require("../data/users.json");

const SECRET = "supergeheim";

router.post("/login", async (req, res) => {
  const { username, password } = req.body;
  const user = users.find(u => u.username === username);

  if (!user) return res.status(401).json({ error: "Gebruiker bestaat niet" });

  const match = await bcrypt.compare(password, user.password);
  if (!match) return res.status(401).json({ error: "Wachtwoord ongeldig" });

  const token = jwt.sign({ id: user.id, role: user.role }, SECRET, { expiresIn: "8h" });

  res.json({ token, role: user.role });
});

module.exports = router;
EOF

# orders.js
cat << 'EOF' > routes/orders.js
const express = require("express");
const router = express.Router();
const { broadcast } = require("../sockets");
const orders = require("../data/orders.json");
const auth = require("../middleware/authMiddleware");

router.get("/", auth(), (req, res) => {
  res.json(orders);
});

router.post("/add", auth("planner"), (req, res) => {
  const order = req.body;
  orders.nieuw.push(order);

  broadcast({ type: "ORDER_UPDATE", data: orders });

  res.json({ success: true });
});

module.exports = router;
EOF

# dashboard.js
cat << 'EOF' > routes/dashboard.js
const express = require("express");
const router = express.Router();
const auth = require("../middleware/authMiddleware");

router.get("/chauffeurs", auth(), (req, res) => {
  res.json([
    { naam: "Jan", ritten: 12, status: "Actief" },
    { naam: "Piet", ritten: 9, status: "In Rust" }
  ]);
});

router.get("/routes", auth(), (req, res) => {
  res.json([
    { routeId: "R001", stops: 14, chauffeur: "Jan" },
    { routeId: "R002", stops: 8, chauffeur: "Piet" }
  ]);
});

router.get("/voertuigen", auth("admin"), (req, res) => {
  res.json([
    { id: 1, type: "Bakwagen", status: "Onderweg" },
    { id: 2, type: "Trailer", status: "Garage" }
  ]);
});

module.exports = router;
EOF

# Data
cat << 'EOF' > data/orders.json
{
  "nieuw": [],
  "oud": [],
  "verzonden": [],
  "aangekomen": []
}
EOF

cat << 'EOF' > data/users.json
[
  { "id": 1, "username": "admin", "password": "$2a$10$M5MRksZiV3AqCYpP7K53o.f2MqSeHTJEwShcEz7hDma0D6K9oLhOC", "role": "admin" },
  { "id": 2, "username": "planner", "password": "$2a$10$M5MRksZiV3AqCYpP7K53o.f2MqSeHTJEwShcEz7hDma0D6K9oLhOC", "role": "planner" },
  { "id": 3, "username": "chauffeur", "password": "$2a$10$M5MRksZiV3AqCYpP7K53o.f2MqSeHTJEwShcEz7hDma0D6K9oLhOC", "role": "chauffeur" }
]
EOF

cd ..

###############################################
# FRONTEND
###############################################

echo "🎨 Frontend installeren..."
cd transport-dashboard

npm create vite@latest . --template react >/dev/null
npm install >/dev/null
npm install react-router-dom axios >/dev/null
npm install -D tailwindcss postcss autoprefixer >/dev/null
npx tailwindcss init -p >/dev/null

echo "🔧 Tailwind configureren..."
sed -i '' 's/content: .*/content: [".\/index.html", ".\/src\/**\/*.{js,jsx,ts,tsx}"],/' tailwind.config.js

cat << 'EOF' > src/index.css
@tailwind base;
@tailwind components;
@tailwind utilities;
EOF

mkdir -p src/pages src/layout
# You will paste your UI files manually later

cd ..

###############################################
# FINISH
###############################################

echo "======================================"
echo "🎉 INSTALLATIE VOLTOOID!"
echo ""
echo "Backend:  http://localhost:3000"
echo "Frontend: http://localhost:5173"
echo ""
echo "Start handmatig via:"
echo "cd transport-backend && node server.js"
echo "cd transport-dashboard && npm run dev"
echo "======================================"
echo ""
