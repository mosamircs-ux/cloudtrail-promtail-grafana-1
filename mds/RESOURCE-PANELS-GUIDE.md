# 🎯 دليل الـ Resource Panels - EC2, S3, RDS, Lambda

## ✨ الـ Panels الجديدة المخصصة

تم إضافة **4 panels جديدة**، كل واحد مخصص لـ Resource معين!

---

## 📊 الـ Panels الأربعة

### 1. 💻 EC2 - اتستخدم امتى ومين عمل إيه
**Panel ID**: 44  
**اللون**: أزرق 🔵  
**الموقع**: أسفل الـ Dashboard

#### ما اللي هتشوفه:
```
┌────────────────────────────────────────────────────────────────┐
│ When    │ Action      │ EC2 Instance │ Access Key │ User │ IP │
├─────────┼─────────────┼──────────────┼────────────┼──────┼────┤
│ 15:30   │ RunInstances│ i-123abc     │ AKIA...    │ user │ IP │
│ 15:25   │ StopInstances│ i-456def    │ AKIA...    │ user │ IP │
└────────────────────────────────────────────────────────────────┘
```

#### الأعمدة:
- ⏰ **When (امتى)**: الوقت
- ⚡ **Action (عمل إيه)**: RunInstances, StopInstances, TerminateInstances, إلخ
- 💻 **EC2 Instance**: Instance ID
- 🔑 **Access Key (مين)**: الـ Access Key اللي استخدمه
- 👤 **User**: الـ User/Principal
- 🌐 **IP**: Source IP
- 🌍 **Region**: AWS Region
- ✅ **Status**: Success أو Failed

---

### 2. 🪣 S3 - اتستخدم امتى ومين عمل إيه
**Panel ID**: 46  
**اللون**: برتقالي 🟠  
**الموقع**: جنب EC2 Panel

#### ما اللي هتشوفه:
```
┌────────────────────────────────────────────────────────────────┐
│ When    │ Action    │ S3 Bucket    │ Access Key │ User │ IP  │
├─────────┼───────────┼──────────────┼────────────┼──────┼─────┤
│ 15:30   │ PutObject │ my-bucket    │ AKIA...    │ user │ IP  │
│ 15:25   │ GetObject │ prod-bucket  │ AKIA...    │ user │ IP  │
└────────────────────────────────────────────────────────────────┘
```

#### الأعمدة:
- ⏰ **When (امتى)**: الوقت
- ⚡ **Action (عمل إيه)**: PutObject, GetObject, DeleteObject, إلخ
- 🪣 **S3 Bucket**: Bucket name/ARN
- 🔑 **Access Key (مين)**: الـ Access Key
- 👤 **User**: الـ User/Principal
- 🌐 **IP**: Source IP
- 🌍 **Region**: AWS Region
- ✅ **Status**: Success أو Failed

---

### 3. 🗄️ RDS - اتستخدم امتى ومين عمل إيه
**Panel ID**: 48  
**اللون**: بنفسجي 🟣  
**الموقع**: تحت EC2 Panel

#### ما اللي هتشوفه:
```
┌────────────────────────────────────────────────────────────────┐
│ When    │ Action          │ RDS Database │ Access Key │ User │
├─────────┼─────────────────┼──────────────┼────────────┼──────┤
│ 15:30   │ CreateDBInstance│ prod-db      │ AKIA...    │ user │
│ 15:25   │ ModifyDBInstance│ dev-db       │ AKIA...    │ user │
└────────────────────────────────────────────────────────────────┘
```

#### الأعمدة:
- ⏰ **When (امتى)**: الوقت
- ⚡ **Action (عمل إيه)**: CreateDBInstance, ModifyDBInstance, إلخ
- 🗄️ **RDS Database**: Database identifier
- 🔑 **Access Key (مين)**: الـ Access Key
- 👤 **User**: الـ User/Principal
- 🌐 **IP**: Source IP
- 🌍 **Region**: AWS Region
- ✅ **Status**: Success أو Failed

---

### 4. ⚡ Lambda - اتستخدم امتى ومين عمل إيه
**Panel ID**: 50  
**اللون**: أخضر 🟢  
**الموقع**: جنب RDS Panel

#### ما اللي هتشوفه:
```
┌────────────────────────────────────────────────────────────────┐
│ When    │ Action         │ Lambda Function │ Access Key │ User│
├─────────┼────────────────┼─────────────────┼────────────┼─────┤
│ 15:30   │ CreateFunction │ my-function     │ AKIA...    │ user│
│ 15:25   │ InvokeFunction │ api-handler     │ AKIA...    │ user│
└────────────────────────────────────────────────────────────────┘
```

#### الأعمدة:
- ⏰ **When (امتى)**: الوقت
- ⚡ **Action (عمل إيه)**: CreateFunction, InvokeFunction, إلخ
- ⚡ **Lambda Function**: Function name/ARN
- 🔑 **Access Key (مين)**: الـ Access Key
- 👤 **User**: الـ User/Principal
- 🌐 **IP**: Source IP
- 🌍 **Region**: AWS Region
- ✅ **Status**: Success أو Failed

---

## 🎯 كيف تستخدم الـ Panels؟

### الطريقة 1: شوف كل الـ Resources
```bash
1. اختار "All" من Variable $access_key
2. كل panel هيعرض كل الـ activities للـ Resource ده
3. شوف EC2 Panel → كل EC2 activities
4. شوف S3 Panel → كل S3 activities
5. شوف RDS Panel → كل RDS activities
6. شوف Lambda Panel → كل Lambda activities
```

### الطريقة 2: فلتر حسب Access Key
```bash
1. اضغط على Access Key في Panel الرئيسي (Panel 36)
2. كل الـ 4 Panels هتتفلتر تلقائياً
3. هتشوف بس الـ activities للـ Key ده
```

### الطريقة 3: استخدم الـ Variable
```bash
1. اختار Access Key من Variable في الأعلى
2. كل الـ Panels هتتحدث
```

---

## 🎨 الألوان والمعاني

### الـ Actions (عمل إيه)
- 💻 **EC2**: أزرق 🔵
- 🪣 **S3**: برتقالي 🟠
- 🗄️ **RDS**: بنفسجي 🟣
- ⚡ **Lambda**: أخضر 🟢

### الـ Status
- ✅ **Success**: أخضر
- ❌ **Failed**: أحمر

---

## 📋 أمثلة عملية

### مثال 1: معرفة مين استخدم EC2 امتى
```bash
هدف: عايز أعرف كل الـ EC2 activities

خطوات:
1. روح لـ Panel: 💻 EC2
2. شوف العمود "When" → الوقت
3. شوف العمود "Action" → عمل إيه
4. شوف العمود "Access Key" → مين

نتيجة:
✅ عرفت مين استخدم EC2 وعمل إيه وامتى!
```

### مثال 2: تدقيق S3 Bucket
```bash
هدف: عايز أعرف مين وصل لـ S3 buckets

خطوات:
1. روح لـ Panel: 🪣 S3
2. شوف العمود "S3 Bucket" → اسم الـ bucket
3. شوف العمود "Action" → عمل إيه (Put/Get/Delete)
4. شوف العمود "Access Key" → مين

نتيجة:
✅ عرفت مين وصل للـ buckets وعمل إيه!
```

### مثال 3: مراقبة RDS Changes
```bash
هدف: عايز أعرف أي تغييرات على RDS

خطوات:
1. روح لـ Panel: 🗄️ RDS
2. شوف العمود "Action" → دور على Create/Modify/Delete
3. شوف العمود "RDS Database" → أي database
4. شوف العمود "Status" → نجح ولا فشل

نتيجة:
✅ عرفت كل التغييرات على RDS!
```

### مثال 4: Lambda Invocations
```bash
هدف: عايز أعرف أي Lambda functions اتنفذت

خطوات:
1. روح لـ Panel: ⚡ Lambda
2. شوف العمود "Action" → دور على InvokeFunction
3. شوف العمود "Lambda Function" → أي function
4. شوف العمود "When" → امتى

نتيجة:
✅ عرفت أي functions اتنفذت وامتى!
```

---

## 🔍 الـ Queries المستخدمة

### EC2 Panel
```logql
{job="cloudtrail", event_source="ec2.amazonaws.com", access_key_id=~"$access_key"} | json
```

### S3 Panel
```logql
{job="cloudtrail", event_source="s3.amazonaws.com", access_key_id=~"$access_key"} | json
```

### RDS Panel
```logql
{job="cloudtrail", event_source="rds.amazonaws.com", access_key_id=~"$access_key"} | json
```

### Lambda Panel
```logql
{job="cloudtrail", event_source="lambda.amazonaws.com", access_key_id=~"$access_key"} | json
```

---

## 💡 نصائح

### 1. استخدم الترتيب
كل panel مرتب حسب الوقت (الأحدث أولاً)

### 2. راقب الـ Status
- ✅ أخضر = نجح
- ❌ أحمر = فشل

### 3. تابع الـ IPs
العمود "IP" يساعدك تعرف مصدر الـ request

### 4. استخدم الـ Region
العمود "Region" يساعدك تعرف فين حصل الـ activity

---

## 📊 Layout الـ Panels

```
┌─────────────────────────────────────────────────────┐
│  ... Panels السابقة ...                            │
├──────────────────────────┬──────────────────────────┤
│ 💻 EC2                   │ 🪣 S3                    │
│ اتستخدم امتى ومين       │ اتستخدم امتى ومين       │
│ عمل إيه                  │ عمل إيه                  │
├──────────────────────────┼──────────────────────────┤
│ 🗄️ RDS                   │ ⚡ Lambda                │
│ اتستخدم امتى ومين       │ اتستخدم امتى ومين       │
│ عمل إيه                  │ عمل إيه                  │
└──────────────────────────┴──────────────────────────┘
```

---

## ✅ Checklist

- [ ] افتح الـ Dashboard
- [ ] Scroll لآخر الـ Dashboard
- [ ] لاقي الـ 4 Panels الجديدة
- [ ] شوف 💻 EC2 Panel
- [ ] شوف 🪣 S3 Panel
- [ ] شوف 🗄️ RDS Panel
- [ ] شوف ⚡ Lambda Panel
- [ ] جرب الفلترة بـ Access Key
- [ ] راقب الـ Status (✅/❌)

---

## 🎯 الفوائد

### ✅ وضوح كامل
كل Resource في panel منفصل

### ✅ سهولة المتابعة
عناوين واضحة بالعربي والإنجليزي

### ✅ ألوان مميزة
كل Resource له لون خاص

### ✅ تفاصيل شاملة
- امتى (When)
- مين (Who)
- عمل إيه (What)
- فين (Where)
- نجح ولا فشل (Status)

---

## 🚀 ابدأ الآن!

```bash
1. افتح Grafana Dashboard
2. Scroll لآخر الـ Dashboard
3. شوف الـ 4 Panels الجديدة
4. اختار Access Key (اختياري)
5. راقب كل Resource بشكل منفصل!
```

---

## 📞 الملفات ذات الصلة

- [EASY-USAGE-GUIDE.md](./EASY-USAGE-GUIDE.md) - دليل الاستخدام السهل
- [QUICK-REFERENCE.md](./QUICK-REFERENCE.md) - مرجع سريع للـ queries
- [DASHBOARD-UPDATE-README.md](./DASHBOARD-UPDATE-README.md) - نظرة عامة

---

**تم بنجاح! 🎉**

دلوقتي عندك 4 panels مخصصة:
- ✅ 💻 EC2 - واضح ومنظم
- ✅ 🪣 S3 - واضح ومنظم
- ✅ 🗄️ RDS - واضح ومنظم
- ✅ ⚡ Lambda - واضح ومنظم

**كل Resource بشكل منفصل وواضح! 🎯**
