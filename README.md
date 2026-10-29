# Hardware Accelerator for Depthwise Convolution (Edge AI)

## 📌 Project Overview
- **Topic:** Hardware Architecture Design for Depthwise Convolution Layer (MobileNetV1).
- **Authors:** Nguyễn Việt Linh & Vũ Hàn Tín
- **Advisor:** TS. Nguyễn Kiêm Hùng

## 🛠 Repository Structure
- `golden_model/`: Python reference model for bit-exact verification.
- `rtl/`: SystemVerilog hardware implementation files.
- `tb/`: SystemVerilog testbenches for functional verification.
- `docs/`: Weekly progress reports and technical documentation.

## 🚀 How to Run Golden Model
```bash
pip install -r requirements.txt
python golden_model/golden_model.py
