const express = require("express");

const app = express();

const PORT = process.env.PORT || 3000;

app.get("/", (req, res) => {
    res.send("🚀 Production EKS GitOps Project is Running!");
});

app.get("/health", (req, res) => {
    res.json({
        status: "UP",
        application: "Production-EKS-GitOps",
        version: "1.0.0"
    });
});

app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});
