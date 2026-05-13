# Coraline Challenge — Infrastructure & Architecture

---

## ข้อที่ 1: Infrastructure for Metabase

### ภาพรวม

ระบบนี้ deploy Metabase พร้อม PostgreSQL บน AWS โดยใช้ Terraform จัดการ infrastructure ทั้งหมด แบ่งโครงสร้างออกเป็น public subnet สำหรับ EC2 ที่รัน Metabase ผ่าน Docker และ private subnet สำหรับ RDS PostgreSQL ซึ่งไม่สามารถเข้าถึงได้จาก public network โดยตรง การเข้าถึง database ทำได้เฉพาะผ่าน EC2 เท่านั้น โดย Security Group ของ RDS อนุญาตเฉพาะ connection จาก Security Group ของ EC2

```
Internet → Internet Gateway → EC2 t3.small (Metabase on Docker)
                                      ↓
                              RDS PostgreSQL db.t3.micro
                              (Private Subnet, no public access)
```

### สิ่งที่ใช้

- **Terraform** จัดการ infrastructure ทั้งหมดแบบ IaC
- **AWS EC2 t3.small** รัน Metabase ผ่าน Docker
- **AWS RDS db.t3.micro** PostgreSQL 15 อยู่ใน private subnet
- **AWS SSM Parameter Store** เก็บ database password แบบ SecureString (encrypted)
- **AWS IAM Role** ให้ EC2 มีสิทธิ์อ่านเฉพาะ secret ที่จำเป็น (least privilege)
- **S3 Backend** เก็บ Terraform state เพื่อให้ทุกคนและ CI/CD ใช้ state เดียวกัน
- **GitHub Actions** สำหรับ CI/CD pipeline

### โครงสร้างไฟล์

```
.
├── main.tf              # Provider config และ S3 backend
├── vpc.tf               # VPC, Subnet, Internet Gateway, Route Table
├── security_groups.tf   # Security Group สำหรับ EC2 และ RDS
├── ec2.tf               # EC2 instance และ IAM Role
├── rds.tf               # RDS PostgreSQL
├── ssm.tf               # SSM Parameter Store
├── variables.tf         # ตัวแปรทั้งหมด
├── outputs.tf           # Output หลัง deploy
├── user_data.sh         # Script ติดตั้ง Docker และรัน Metabase
├── .github/
│   └── workflows/
│       ├── ci.yml       # ตรวจสอบ Terraform code เมื่อเปิด PR
│       ├── cd.yml       # Deploy infrastructure
│       └── destroy.yml  # ลบ infrastructure ทั้งหมด
└── README.md
```

### Prerequisites

- AWS Account
- Terraform >= 1.0
- AWS CLI configured (`aws configure`)
- SSH key pair สำหรับเข้า EC2

### GitHub Secrets ที่ต้องตั้งค่า

ไปที่ Settings → Secrets and variables → Actions แล้วเพิ่ม:

| Secret | คำอธิบาย |
|---|---|
| `AWS_ACCESS_KEY_ID` | AWS Access Key ID |
| `AWS_SECRET_ACCESS_KEY` | AWS Secret Access Key |
| `TF_VAR_DB_PASSWORD` | Password สำหรับ PostgreSQL |
| `SSH_PUBLIC_KEY` | SSH public key content สำหรับเข้า EC2 |

### วิธี Deploy

**ผ่าน GitHub Actions (แนะนำ):**

1. ไปที่ Actions → CD — Deploy Infrastructure
2. กด Run workflow
3. รอประมาณ 15-20 นาที (RDS ใช้เวลานานสุด)
4. URL ของ Metabase จะแสดงใน Job Summary หลัง deploy เสร็จ

**ผ่านเครื่องตัวเอง:**

```bash
terraform init
terraform plan
terraform apply
```

### วิธีทดสอบ

1. เปิด browser ไปที่ URL จาก output เช่น `http://<public-ip>:3000`
2. รอประมาณ 3-5 นาทีให้ Metabase boot ครั้งแรก
3. ตั้งค่า admin account
4. เชื่อมต่อ PostgreSQL โดยใช้ค่าดังนี้:
   - Host: ค่าจาก `terraform output rds_endpoint`
   - Port: 5432
   - Database: metabase
   - Username: metabase_user
5. ทดสอบว่า RDS ไม่เปิด public โดยลอง connect จากเครื่องตัวเองตรงๆ จะต้อง timeout

### วิธีลบ Infrastructure

ไปที่ Actions → Destroy Infrastructure → Run workflow

### Assumptions

- ใช้ region `ap-southeast-1` (Singapore) เพราะใกล้ไทยและ latency ต่ำ
- ใช้ EC2 `t3.small` เพราะ Metabase ต้องการ RAM อย่างน้อย 1.5GB ขึ้นไป `t2.micro` ไม่เพียงพอ
- `skip_final_snapshot = true` เหมาะสำหรับ dev/demo เท่านั้น
- SSH port 22 เปิด `0.0.0.0/0` เพื่อความสะดวกในการ demo production ควรจำกัด IP หรือใช้ SSM Session Manager
- ไม่มี HTTPS เข้าถึงผ่าน port 3000 ตรงๆ production ควรใช้ ALB + ACM Certificate
- Terraform state เก็บใน S3 bucket เพื่อให้ทั้ง local และ GitHub Actions ใช้ state เดียวกัน

### สิ่งที่ควรเปลี่ยนสำหรับ Production

| รายการ | Demo (ที่ทำ) | Production |
|---|---|---|
| EC2 | t3.small | t3.medium+ หรือ ECS Fargate |
| RDS | Single-AZ, ไม่มี backup | Multi-AZ, backup 7 วัน |
| HTTPS | ไม่มี | ALB + ACM + Route53 |
| SSH | Port 22 เปิดกว้าง | AWS SSM Session Manager |
| Secret | SSM Parameter Store | AWS Secrets Manager + auto-rotation |
| Monitoring | ไม่มี | CloudWatch + Prometheus + Grafana |
| IAM | AdministratorAccess | Least-privilege custom policy |

---

## ข้อที่ 2: Architecture & CI/CD Pipeline
> หมายเหตุ: ข้อที่ 2 เป็น architecture design ตามโจทย์ที่กำหนด
> ออกแบบโดยอ้างอิงจากการศึกษา AWS best practices และ
> ประสบการณ์ด้าน infrastructure จากการทำงานที่ผ่านมา

### ภาพรวม Architecture

ระบบ web application ภายในองค์กรประกอบด้วย 3 service หลักที่รันบน AWS ECS Fargate แยกกัน สามารถ scale และ deploy แต่ละ service ได้อิสระโดยไม่กระทบกัน

```
Users
  ↓
Route53 (DNS)
  ↓
ALB (Application Load Balancer)
  ├── /          → Frontend Service (Web UI)
  ├── /api/*     → API Service (Backend)
  └── /airflow/* → Airflow Service (Workflow Orchestration)
          ↓
     RDS PostgreSQL (Private Subnet)
          ↓
     External Data Sources
     ├── On-premise DB  → Site-to-Site VPN
     ├── External APIs  → NAT Gateway (outbound only)
     └── Cloud DB       → VPC Peering
```

### การแบ่ง Environment

ระบบแบ่งเป็น 3 environment โดยแต่ละ environment มี infrastructure และ config แยกกันชัดเจน

**Dev**
- Deploy อัตโนมัติเมื่อ push ไปยัง `feature/*` branch
- Infrastructure ขนาดเล็ก ประหยัดค่าใช้จ่าย
- ใช้สำหรับ developer ทดสอบ feature ใหม่
- Config จาก SSM `/dev/*`

**Staging**
- Deploy อัตโนมัติเมื่อ merge เข้า `main` branch
- Infrastructure ใกล้เคียง production
- ใช้สำหรับ QA ทดสอบก่อน release
- Config จาก SSM `/staging/*`

**Production**
- Deploy เมื่อสร้าง tag รูปแบบ `v*.*.*` และผ่าน manual approve
- Infrastructure Multi-AZ พร้อม Auto-scaling
- Config จาก SSM `/prod/*` encrypted ด้วย KMS

### CI/CD Pipeline

**Application Pipeline**

```
git push
    ↓
GitHub Actions trigger
    ├── lint
    ├── unit tests
    ├── build Docker image
    ├── push image ไปยัง ECR (tag: git-sha)
    └── deploy ตาม branch
         ├── feature/* → DEV (auto)
         ├── main      → STAGING (auto + integration tests)
         └── v*.*.*    → PROD (manual approve → rolling deploy)
```

**Infrastructure Pipeline (แยกจาก App Pipeline)**

Terraform รัน workflow แยกต่างหากจาก application เพื่อควบคุมการเปลี่ยนแปลง infrastructure ได้ชัดเจน

```
แก้ไข Terraform code → เปิด PR → CI validate + plan
    ↓ (merge to main)
terraform apply → staging
    ↓ (manual approve)
terraform apply → production
```

### การจัดการ Configuration และ Secret

**App Config** (ค่าที่ไม่ sensitive เช่น feature flags, timeout)
- เก็บใน SSM Parameter Store แยก prefix ตาม environment (`/dev/*`, `/staging/*`, `/prod/*`)
- ECS Task ดึงค่าตอน startup อัตโนมัติ

**Secret** (passwords, API keys, credentials)
- เก็บใน AWS Secrets Manager
- ECS Task Role มีสิทธิ์อ่านเฉพาะ secret ของ environment ตัวเองเท่านั้น
- ไม่มี secret ใน source code หรือ Docker image ทุกอย่างดึงตอน runtime

**External System**
- On-premise database: เชื่อมผ่าน AWS Site-to-Site VPN credentials เก็บใน Secrets Manager
- External API: API key เก็บใน Secrets Manager outbound ผ่าน NAT Gateway
- Cloud database: เชื่อมผ่าน VPC Peering

### การดูแลเสถียรภาพของระบบ

**การป้องกัน**
- ECS rolling deploy โดย task ใหม่จะรับ traffic ก็ต่อเมื่อ `GET /health` ผ่านแล้วเท่านั้น
- ถ้า task ใหม่ไม่ผ่าน health check ECS จะหยุด deploy และ rollback อัตโนมัติ
- RDS Multi-AZ failover อัตโนมัติถ้า primary instance มีปัญหา
- Auto-scaling ตาม CPU และ memory เพื่อรองรับ traffic ที่เพิ่มขึ้น

**การเฝ้าระวัง**
- CloudWatch เก็บ metrics และ logs ทุก service retention 30 วัน
- Prometheus + Grafana สำหรับ real-time monitoring และ dashboard (ใช้ร่วมกับ CloudWatch ได้)
- ELK Stack สำหรับ centralized logging และ log analysis
- ALB Health Check ตรวจสอบ `GET /health` ทุก 30 วินาที

**Alerting**
- CloudWatch Alarms ส่ง alert ผ่าน SNS ไปยัง Slack
- Alert หลักที่ตั้งไว้:
  - Error rate > 1%
  - P99 latency > 2 วินาที
  - CPU > 80% ต่อเนื่อง 5 นาที
  - RDS storage เหลือน้อยกว่า 20%

**การรับมือเมื่อเกิดปัญหา**
- ECS rollback ได้ทันทีโดยสั่ง deploy task definition เวอร์ชันก่อนหน้า
- มี Runbook สำหรับ incident แต่ละประเภท
- Post-mortem ทุกครั้งที่เกิดปัญหากระทบ user

### การ Promote ระหว่าง Environment

```
สร้าง feature branch และเปิด PR
    ↓
CI ตรวจสอบ lint, test, build ผ่านทั้งหมด
    ↓
Code review ผ่าน → merge เข้า main
    ↓
Auto deploy ไปยัง STAGING
    ↓
Integration tests + QA ทดสอบ
    ↓
QA sign-off → สร้าง release tag เช่น v1.2.0
    ↓
Manual approve → deploy ไปยัง PRODUCTION
    ↓
Monitor error rate และ latency หลัง deploy
    ↓
ถ้ามีปัญหา → rollback ผ่าน ECS task definition เวอร์ชันก่อนหน้า
```
