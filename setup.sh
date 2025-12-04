#!/bin/bash

echo "🚚 Transport Dashboard Installer (macOS)"
echo "======================================="

sleep 1

# Node.js check
if ! command -v node &> /dev/null
then
    echo "Node.js niet gevonden! Installeren via Homebrew..."
    brew install node
else
    echo "✔ Node.js OK"
fi

sleep 1

# Project mappen
mkdir -p transport-backend transport-dashboard

###############################################
# BACKEND
###############################################
cd transport-backend
npm init -y >/dev/null
npm install express cors ws jsonwebtoken bcryptjs >/dev/null

mkdir -p routes middleware data

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
const server = http.createServer(app);
const WebSocket = require("ws");
const wss = new WebSocket.Server({ server });
let clients = [];
wss.on("connection", ws => { clients.push(ws); ws.on("close", ()=>clients = clients.filter(c=>c!==ws)); });
global.broadcast = (data) => clients.forEach(c => { try { c.send(JSON.stringify(data)); } catch{} });
server.listen(3000, ()=>console.log("🚀 Backend live op http://localhost:3000"));
EOF

# routes/auth.js
cat << 'EOF' > routes/auth.js
const express = require("express");
const jwt = require("jsonwebtoken");
const bcrypt = require("bcryptjs");
const router = express.Router();
const users = require("../data/users.json");
const SECRET = "supergeheim";
router.post("/login", async (req,res)=>{
  const { username,password } = req.body;
  const user = users.find(u=>u.username===username);
  if(!user) return res.status(401).json({error:"Gebruiker bestaat niet"});
  const match = await bcrypt.compare(password,user.password);
  if(!match) return res.status(401).json({error:"Wachtwoord ongeldig"});
  const token = jwt.sign({id:user.id,role:user.role},SECRET,{expiresIn:"8h"});
  res.json({token,role:user.role});
});
module.exports = router;
EOF

# routes/orders.js
cat << 'EOF' > routes/orders.js
const express = require("express");
const router = express.Router();
const orders = require("../data/orders.json");
router.get("/", (req,res)=>res.json(orders));
router.post("/add",(req,res)=>{
  const order=req.body;
  orders.nieuw.push(order);
  global.broadcast({type:"ORDER_UPDATE",data:orders});
  res.json({success:true});
});
module.exports = router;
EOF

# demo data
cat << 'EOF' > data/orders.json
{"nieuw":[{"id":1,"omschrijving":"Order A"},{"id":2,"omschrijving":"Order B"}],"oud":[],"verzonden":[],"aangekomen":[]}
EOF

cat << 'EOF' > data/users.json
[
{"id":1,"username":"admin","password":"$2a$10$M5MRksZiV3AqCYpP7K53o.f2MqSeHTJEwShcEz7hDma0D6K9oLhOC","role":"admin"},
{"id":2,"username":"planner","password":"$2a$10$M5MRksZiV3AqCYpP7K53o.f2MqSeHTJEwShcEz7hDma0D6K9oLhOC","role":"planner"},
{"id":3,"username":"chauffeur","password":"$2a$10$M5MRksZiV3AqCYpP7K53o.f2MqSeHTJEwShcEz7hDma0D6K9oLhOC","role":"chauffeur"}
]
EOF

cd ..

###############################################
# FRONTEND
###############################################
cd transport-dashboard
npm create vite@latest . --template react >/dev/null
npm install >/dev/null
npm install react-router-dom axios >/dev/null
npm install -D tailwindcss postcss autoprefixer >/dev/null
npx tailwindcss init -p >/dev/null
sed -i '' 's/content: .*/content: [".\/index.html", ".\/src\/**\/*.{js,jsx,ts,tsx}"],/' tailwind.config.js
cat << 'EOF' > src/index.css
@tailwind base;
@tailwind components;
@tailwind utilities;
EOF

# src/main.jsx
cat << 'EOF' > src/main.jsx
import React from "react";
import ReactDOM from "react-dom/client";
import { BrowserRouter } from "react-router-dom";
import App from "./App";
import "./index.css";
ReactDOM.createRoot(document.getElementById("root")).render(<BrowserRouter><App /></BrowserRouter>);
EOF

# src/App.jsx
cat << 'EOF' > src/App.jsx
import React from "react";
import { Routes, Route, Navigate } from "react-router-dom";
import Login from "./pages/Login";
import Dashboard from "./pages/Dashboard";
function App() {
  const token = localStorage.getItem("token");
  return (
    <Routes>
      <Route path="/login" element={<Login />} />
      <Route path="/dashboard" element={token?<Dashboard/>:<Navigate to="/login"/>} />
      <Route path="*" element={<Navigate to={token?"/dashboard":"/login"} />} />
    </Routes>
  );
}
export default App;
EOF

mkdir -p src/pages src/layout

# src/layout/MainLayout.jsx
cat << 'EOF' > src/layout/MainLayout.jsx
import React from "react";
export default function MainLayout({ children }) {
  return (
    <div className="min-h-screen bg-gray-100">
      <header className="bg-blue-600 text-white p-4 font-bold">Transport Dashboard</header>
      <main className="p-4">{children}</main>
    </div>
  );
}
EOF

# src/pages/Login.jsx
cat << 'EOF' > src/pages/Login.jsx
import React,{useState} from "react";
import axios from "axios";
import { useNavigate } from "react-router-dom";
export default function Login(){
  const [username,setUsername]=useState("");
  const [password,setPassword]=useState("");
  const [error,setError]=useState("");
  const navigate=useNavigate();
  const submit=async()=>{
    try{
      const res=await axios.post("http://localhost:3000/auth/login",{username,password});
      localStorage.setItem("token",res.data.token);
      localStorage.setItem("role",res.data.role);
      navigate("/dashboard");
    }catch(err){
      setError(err.response?.data?.error||"Fout bij inloggen");
    }
  };
  return(
    <div className="flex items-center justify-center h-screen">
      <div className="bg-white p-6 rounded shadow-md w-96">
        <h2 className="text-2xl font-bold mb-4">Login</h2>
        {error&&<p className="text-red-500 mb-2">{error}</p>}
        <input className="border p-2 mb-2 w-full" placeholder="Username" value={username} onChange={e=>setUsername(e.target.value)} />
        <input className="border p-2 mb-4 w-full" type="password" placeholder="Password" value={password} onChange={e=>setPassword(e.target.value)} />
        <button className="bg-blue-600 text-white p-2 w-full" onClick={submit}>Login</button>
      </div>
    </div>
  );
}
EOF

# src/pages/Dashboard.jsx
cat << 'EOF' > src/pages/Dashboard.jsx
import React,{useEffect,useState} from "react";
import MainLayout from "../layout/MainLayout";
import axios from "axios";
export default function Dashboard(){
  const [orders,setOrders]=useState({nieuw:[],oud:[],verzonden:[],aangekomen:[]});
  const token=localStorage.getItem("token");
  useEffect(()=>{
    const fetchOrders=async()=>{
      const res=await axios.get("http://localhost:3000/orders",{headers:{Authorization:`Bearer ${token}`}});
      setOrders(res.data);
    };
    fetchOrders();
    const ws=new WebSocket("ws://localhost:3000");
    ws.onmessage=(msg)=>{
      const data=JSON.parse(msg.data);
      if(data.type==="ORDER_UPDATE") setOrders(data.data);
    };
    return ()=> ws.close();
  },[]);
  return(
    <MainLayout>
      <h1 className="text-2xl font-bold mb-4">Dashboard</h1>
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="bg-white p-4 rounded shadow"><h2 className="font-bold">Nieuwe Orders</h2><p>{orders.nieuw.length}</p></div>
        <div className="bg-white p-4 rounded shadow"><h2 className="font-bold">Oude Orders</h2><p>{orders.oud.length}</p></div>
        <div className="bg-white p-4 rounded shadow"><h2 className="font-bold">Verzonden</h2><p>{orders.verzonden.length}</p></div>
        <div className="bg-white p-4 rounded shadow"><h2 className="font-bold">Aangekomen</h2><p>{orders.aangekomen.length}</p></div>
      </div>
    </MainLayout>
  );
}
EOF

cd ../..

###############################################
# START-ALL SCRIPT
###############################################
cat << 'EOF' > start-all.sh
#!/bin/bash
echo "🚀 Start Transport Platform (Backend + Frontend) ..."
cd transport-backend
node server.js &
BACKEND_PID=$!
cd ../transport-dashboard
npm run dev &
FRONTEND_PID=$!
echo "✅ Alles gestart! Backend PID: $BACKEND_PID, Frontend PID: $FRONTEND_PID"
echo "CTRL+C om te stoppen"
wait
EOF
chmod +x start-all.sh

echo "======================================"
echo "🎉 INSTALLATIE VOLTOOID!"
echo "Gebruik ./start-all.sh om backend + frontend in één terminal te starten!"
