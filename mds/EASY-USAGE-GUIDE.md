# 🎯 دليل الاستخدام السريع - Access Key Tracking

## الطريقة الجديدة السهلة! 🚀

### خطوة واحدة بس: اضغط على Access Key!

## 📊 كيف تستخدم الـ Dashboard

### 1️⃣ Panel الرئيسي: Access Keys Overview

**الموقع**: في آخر الـ Dashboard  
**العنوان**: 🔑 Access Keys Overview - اضغط على أي Access Key لرؤية التفاصيل

#### ما اللي هتشوفه:
```
┌─────────────────────────────────────────────────────────────┐
│ Access Key  │ Total │ EC2 │ S3  │ RDS │ Lambda │ Failed   │
├─────────────┼───────┼─────┼─────┼─────┼────────┼──────────┤
│ AKIA...ABC  │  250  │ 120 │  80 │  30 │   20   │    5     │
│ AKIA...XYZ  │  180  │  50 │ 100 │  20 │   10   │    2     │
└─────────────────────────────────────────────────────────────┘
```

#### الألوان:
- **Total**: Gradient gauge (أخضر → أصفر → برتقالي → أحمر)
- **EC2**: أزرق
- **S3**: برتقالي
- **RDS**: بنفسجي
- **Lambda**: أخضر
- **Failed**: أحمر

---

### 2️⃣ اضغط على Access Key

**كيف؟**
1. روح للـ Panel الرئيسي (🔑 Access Keys Overview)
2. اضغط على أي Access Key في العمود الأول
3. **تلقائياً** كل الـ Panels اللي تحت هتتفلتر!

**إيه اللي هيحصل؟**
- الـ Variable `$access_key` في الأعلى هيتغير
- كل الـ Panels اللي تحت هتعرض بيانات الـ Key ده بس
- هتشوف بالظبط عمل إيه على أي Resource

---

### 3️⃣ شوف التفاصيل في 3 Panels

بعد ما تضغط على Access Key، هتشوف:

#### Panel 1: Resources by Service (📦)
```
┌──────────────────────────────┐
│ AWS Service          │ Count │
├──────────────────────┼───────┤
│ ec2.amazonaws.com    │  120  │
│ s3.amazonaws.com     │   80  │
│ rds.amazonaws.com    │   30  │
│ lambda.amazonaws.com │   20  │
└──────────────────────────────┘
```
**الفايدة**: تعرف الـ Key ده بيستخدم أي Services

---

#### Panel 2: Actions Breakdown (⚡)
```
┌───────────────────────────────────────────┐
│ Service           │ Action         │ Count│
├───────────────────┼────────────────┼──────┤
│ ec2.amazonaws.com │ RunInstances   │  50  │
│ ec2.amazonaws.com │ StopInstances  │  40  │
│ ec2.amazonaws.com │ StartInstances │  30  │
│ s3.amazonaws.com  │ GetObject      │  60  │
│ s3.amazonaws.com  │ PutObject      │  20  │
└───────────────────────────────────────────┘
```
**الفايدة**: تعرف بالظبط عمل إيه على كل Service

---

#### Panel 3: Complete Details (📋)
```
┌────────────────────────────────────────────────────────────────────────────┐
│ Time    │ Key  │ Service │ Action  │ Resource │ IP      │ Region │ Status │
├─────────┼──────┼─────────┼─────────┼──────────┼─────────┼────────┼────────┤
│ 15:30   │ AKIA │ EC2     │ Run...  │ i-123... │ 1.2.3.4 │ us-e-1 │ ✅     │
│ 15:25   │ AKIA │ S3      │ Get...  │ bucket-1 │ 1.2.3.4 │ us-e-1 │ ✅     │
│ 15:20   │ AKIA │ RDS     │ Create..│ db-prod  │ 1.2.3.4 │ us-e-1 │ ❌     │
└────────────────────────────────────────────────────────────────────────────┘
```
**الفايدة**: سجل كامل بكل التفاصيل - مين عمل إيه على أي Resource وامتى وفين

---

## 🎬 مثال عملي

### السيناريو: عايز تعرف Access Key معين عمل إيه

#### الخطوات:

**1. افتح الـ Dashboard**
```
→ روح لآخر الـ Dashboard
→ لاقي Panel: 🔑 Access Keys Overview
```

**2. اختار الـ Access Key**
```
→ دور على الـ Access Key اللي عايزه
→ اضغط عليه
```

**3. شوف النتيجة**
```
✅ Panel 1 (📦): يعرضلك Services (EC2: 120, S3: 80, RDS: 30)
✅ Panel 2 (⚡): يعرضلك Actions (RunInstances: 50, GetObject: 60)
✅ Panel 3 (📋): يعرضلك كل حاجة بالتفصيل
```

**4. اعرف بالظبط**
```
✅ عمل إيه: RunInstances, GetObject, CreateDBInstance
✅ على أي Resource: i-123abc, bucket-prod, db-prod
✅ امتى: 15:30, 15:25, 15:20
✅ فين: us-east-1
✅ نجح ولا فشل: ✅ أو ❌
```

---

## 💡 نصائح سريعة

### 1. استخدم الألوان
- **أزرق** = EC2
- **برتقالي** = S3
- **بنفسجي** = RDS
- **أخضر** = Lambda
- **أحمر** = Failed Actions

### 2. ترتيب الـ Panels
الـ Panels مرتبة من العام للتفصيلي:
1. Overview → شوف كل الـ Keys
2. By Service → شوف الـ Services
3. By Action → شوف الـ Actions
4. Complete → شوف كل حاجة

### 3. استخدم الـ Variable
لو عايز تفلتر يدوياً:
```
→ روح للـ Variable "Access Key" في الأعلى
→ اختار الـ Key اللي عايزه
→ كل الـ Panels هتتحدث
```

---

## 🔍 حالات استخدام شائعة

### Case 1: تدقيق Access Key
```
هدف: عايز أعرف Access Key معين بيعمل إيه

خطوات:
1. اضغط على الـ Key في Panel 1
2. شوف Panel 2 (Services)
3. شوف Panel 3 (Actions)
4. راجع Panel 4 (Complete Details)

نتيجة: عرفت كل حاجة!
```

### Case 2: معرفة مين وصل لـ EC2
```
هدف: عايز أعرف أي Keys وصلت لـ EC2

خطوات:
1. شوف Panel 1 (Overview)
2. دور على عمود "EC2"
3. الـ Keys اللي فيها أرقام = وصلت لـ EC2
4. اضغط على أي Key لمعرفة التفاصيل

نتيجة: عرفت مين وصل لـ EC2!
```

### Case 3: اكتشاف Failed Actions
```
هدف: عايز أعرف أي Keys فيها Failed Actions

خطوات:
1. شوف Panel 1 (Overview)
2. دور على عمود "Failed" (أحمر)
3. الـ Keys اللي فيها أرقام = فيها failures
4. اضغط على الـ Key
5. شوف Panel 4 للتفاصيل

نتيجة: عرفت الـ Failures وإيه سببها!
```

---

## 📱 Quick Reference

### الـ Panels الجديدة (4 panels)

| # | الاسم | الوظيفة | متى تستخدمه |
|---|-------|---------|-------------|
| 36 | 🔑 Access Keys Overview | عرض كل الـ Keys مع breakdown | البداية - اضغط على Key |
| 38 | 📦 Resources by Service | Services المستخدمة | بعد ما تضغط على Key |
| 40 | ⚡ Actions Breakdown | Actions بالتفصيل | لمعرفة الـ Actions |
| 42 | 📋 Complete Details | سجل كامل | للتفاصيل الكاملة |

---

## 🎯 الفرق بين القديم والجديد

### القديم ❌
```
1. اختار Access Key من Variable
2. روح لـ Panel 1
3. روح لـ Panel 2
4. روح لـ Panel 3
5. دور في كل panel
```

### الجديد ✅
```
1. اضغط على Access Key
2. شوف كل حاجة تلقائياً!
```

---

## 🚀 ابدأ دلوقتي!

### الخطوة الأولى
```bash
1. افتح Grafana
2. روح للـ Dashboard: "AWS CloudTrail Monitoring"
3. Scroll لآخر الـ Dashboard
4. لاقي Panel: 🔑 Access Keys Overview
5. اضغط على أي Access Key
6. استمتع! 🎉
```

---

## ❓ الأسئلة الشائعة

### Q: إزاي أرجع للـ Overview؟
**A**: اضغط على "All" في الـ Variable `$access_key` في الأعلى

### Q: الـ Panels فاضية؟
**A**: تأكد إنك اخترت Access Key من Panel 1

### Q: عايز أشوف كل الـ Keys مرة واحدة؟
**A**: اختار "All" من الـ Variable في الأعلى

### Q: إزاي أعرف الـ Key ده عمل إيه على S3 بالظبط؟
**A**: 
1. اضغط على الـ Key في Panel 1
2. شوف Panel 2 → لاقي s3.amazonaws.com
3. شوف Panel 3 → لاقي الـ S3 Actions
4. شوف Panel 4 → شوف الـ Resources بالتفصيل

---

## 🎨 الألوان والمعاني

### Panel 1 (Overview)
- **Total**: 
  - أخضر (< 50)
  - أصفر (50-200)
  - برتقالي (200-500)
  - أحمر (> 500)

### Services
- **EC2**: أزرق 🔵
- **S3**: برتقالي 🟠
- **RDS**: بنفسجي 🟣
- **Lambda**: أخضر 🟢
- **Failed**: أحمر 🔴

### Status
- **✅ Success**: أخضر
- **❌ Failed**: أحمر

---

## 🎉 خلاص!

دلوقتي عندك dashboard سهل جداً:
- ✅ اضغط على Access Key
- ✅ شوف كل حاجة تلقائياً
- ✅ EC2, S3, RDS, Lambda, كله واضح
- ✅ مين عمل إيه وامتى وفين

**استمتع بالمراقبة! 🚀**
