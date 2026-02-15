# CloudTrail Grafana Dashboard - Access Key & Resource Tracking Update

## 🎉 What's New

تم إضافة **7 panels جديدة** للـ Grafana Dashboard لتتبع شامل لـ Access Keys والـ Resources!

## ✨ الميزات الجديدة

### 1. تتبع استخدام Access Keys
- شوف كل Access Key بيستخدم إيه من Resources
- تتبع النشاط عبر الزمن
- إحصائيات شاملة للاستهلاك

### 2. تدقيق الوصول للـ Resources
- اعرف مين عنده Access على كل Resource
- تتبع EC2 Instances
- تتبع S3 Buckets

### 3. سجل نشاط تفصيلي
- مين عمل إيه
- امتى
- فين
- من أي IP
- نجح ولا فشل

### 4. مراقبة الأمان
- اكتشف Failed Actions
- راقب النشاط الغير عادي
- تتبع التغييرات الحساسة

## 📊 الـ Panels الجديدة

| # | اسم الـ Panel | النوع | الوصف |
|---|--------------|-------|-------|
| 1 | Access Key → Resource Usage | Table | ما الذي يستخدمه كل Access Key |
| 2 | Resource → Access Keys | Table | مين عنده Access على كل Resource |
| 3 | Access Key Activity Timeline | Time Series | استخدام Access Keys عبر الزمن |
| 4 | Access Key Consumption Summary | Table | إحصائيات شاملة لكل Key |
| 5 | Detailed Activity Log | Table | سجل تفصيلي لكل العمليات |
| 6 | EC2 Resources → Access Keys | Table | تدقيق الوصول لـ EC2 |
| 7 | S3 Resources → Access Keys | Table | تدقيق الوصول لـ S3 |

## 🚀 كيفية الاستخدام

### الخطوة 1: Import الـ Dashboard
```bash
# في Grafana UI:
# 1. اضغط على "+" في الـ sidebar
# 2. اختر "Import"
# 3. Upload ملف grafana-cloudtrail-dashboard.json
# 4. اختر Loki Data Source
# 5. اضغط "Import"
```

### الخطوة 2: استخدام الـ Variables
الـ Dashboard فيه 3 variables للتصفية:
- **Access Key**: فلتر حسب Access Key معين
- **Event Name**: فلتر حسب نوع الـ Event
- **AWS Region**: فلتر حسب الـ Region

### الخطوة 3: استكشف البيانات
1. ابدأ بـ **Panel 4** (Consumption Summary) لنظرة عامة
2. استخدم **Panel 3** (Timeline) لمراقبة الـ Patterns
3. استخدم **Panel 5** (Activity Log) للتفاصيل

## 📖 الملفات المحدثة

### 1. `grafana-cloudtrail-dashboard.json`
الـ Dashboard الرئيسي مع الـ 7 panels الجديدة

### 2. `QUERY-EXAMPLES.md`
تم إضافة 3 أقسام جديدة:
- **Access Key and Resource Tracking**: 15+ query جديد
- **Resource-Specific Access Tracking**: Queries لـ EC2, S3, RDS, Lambda
- **Access Key Security Monitoring**: Queries للأمان
- **Dashboard Panel Recommendations**: توصيات للـ Panels

### 3. `ACCESS-KEY-TRACKING-GUIDE.md` (جديد)
دليل شامل بالعربي يشرح:
- كل Panel بالتفصيل
- حالات الاستخدام
- الـ Queries المستخدمة
- استكشاف الأخطاء

## 🎯 حالات الاستخدام

### 1. Security Audit
```
هدف: تدقيق أمني شامل لـ Access Keys

الخطوات:
1. افتح Panel 4 (Consumption Summary)
2. دور على Keys بـ Failed Actions عالية
3. راجع تفاصيلها في Panel 5
4. تحقق من الـ Source IPs في Panel 5
```

### 2. Resource Access Review
```
هدف: معرفة مين عنده Access على resource معين

الخطوات:
1. افتح Panel 2 (Resource → Access Keys)
2. دور على الـ Resource (مثلاً: EC2 instance ID)
3. شوف كل الـ Access Keys اللي وصلت له
4. راجع التفاصيل في Panel 5
```

### 3. Access Key Activity Monitoring
```
هدف: مراقبة نشاط Access Key معين

الخطوات:
1. اختر الـ Access Key من الـ Variable في الأعلى
2. شوف Panel 3 للـ Timeline
3. راجع Panel 1 لمعرفة الـ Resources المستخدمة
4. شوف Panel 5 للتفاصيل الكاملة
```

### 4. EC2 Instance Access Audit
```
هدف: معرفة مين عمل إيه على EC2 instance

الخطوات:
1. افتح Panel 6 (EC2 Access Audit)
2. دور على الـ Instance ID
3. شوف كل الـ Actions (Start, Stop, Terminate, etc.)
4. راجع الـ Access Keys المستخدمة
```

### 5. S3 Bucket Access Audit
```
هدف: تتبع الوصول لـ S3 bucket

الخطوات:
1. افتح Panel 7 (S3 Access Audit)
2. دور على الـ Bucket name
3. شوف كل الـ Operations (Get, Put, Delete)
4. راجع مين عمل إيه وامتى
```

## 🔍 أمثلة Queries

### معرفة استخدام Access Key معين
```logql
{job="cloudtrail", access_key_id="AKIAIOSFODNN7EXAMPLE"}
```

### معرفة مين وصل لـ EC2 Instance
```logql
{job="cloudtrail"} |~ "i-0123456789abcdef0"
```

### معرفة مين وصل لـ S3 Bucket
```logql
{job="cloudtrail"} |~ "arn:aws:s3:::my-bucket-name"
```

### Access Keys مع Failed Actions عالية
```logql
sum by (access_key_id) (count_over_time({job="cloudtrail", access_key_id!="N/A", success="false"}[1h])) > 10
```

### Access Keys بتستخدم Regions كتير
```logql
count by (access_key_id) (
  count by (access_key_id, aws_region) (
    count_over_time({job="cloudtrail", access_key_id!="N/A"}[24h])
  )
) > 1
```

## 📈 Dashboard Layout

```
┌─────────────────────────────────────────────────────────────┐
│  CloudTrail Events Over Time (Full Width)                  │
├──────────────────┬──────────────────┬──────────────────────┤
│  Total Events    │  Failed Events   │  Unique Access Keys  │
├──────────────────┴──────────────────┴──────────────────────┤
│  Events by Access Key (Pie)  │  Top Event Names (Pie)     │
├───────────────────────────────┴────────────────────────────┤
│  Recent CloudTrail Events (Table)                          │
├────────────────────────────────────────────────────────────┤
│  Failed Events (Table)                                     │
├───────────────────────────────┬────────────────────────────┤
│  Events by Region (Pie)       │  Events by User Type (Pie)│
├───────────────────────────────┴────────────────────────────┤
│  🆕 Access Key → Resource Usage │ 🆕 Resource → Access Keys│
├───────────────────────────────┴────────────────────────────┤
│  🆕 Access Key Activity Timeline (Full Width)              │
├────────────────────────────────────────────────────────────┤
│  🆕 Access Key Consumption Summary (Full Width)            │
├────────────────────────────────────────────────────────────┤
│  🆕 Detailed Activity Log (Full Width)                     │
├───────────────────────────────┬────────────────────────────┤
│  🆕 EC2 Access Audit          │ 🆕 S3 Access Audit        │
└───────────────────────────────┴────────────────────────────┘
```

## 🛠️ Technical Details

### Panel IDs
- Panel 22: Access Key → Resource Usage
- Panel 24: Resource → Access Keys
- Panel 26: Access Key Activity Timeline
- Panel 28: Access Key Consumption Summary
- Panel 30: Detailed Activity Log
- Panel 32: EC2 Access Audit
- Panel 34: S3 Access Audit

### Data Source
- **Type**: Loki
- **Job Label**: `cloudtrail`
- **Required Labels**: 
  - `access_key_id`
  - `event_name`
  - `success`
  - `aws_region`
  - `principal_id`
  - `source_ip`

### Transformations Used
- `groupBy`: لتجميع البيانات
- `organize`: لترتيب الأعمدة
- `extractFields`: لاستخراج JSON fields

## 🎨 Visualizations

### Colors
- **Green**: Successful operations
- **Red**: Failed operations
- **Yellow**: Warning threshold (100-500 actions)
- **Orange**: High usage (500-1000 actions)

### Gauges
- **Gradient Gauge**: للـ Total Actions
- **Color Background**: للـ Failed Actions
- **Thresholds**: 
  - < 100: Green
  - 100-500: Yellow
  - 500-1000: Orange
  - > 1000: Red

## 📚 Documentation

### للمزيد من المعلومات:
1. **[ACCESS-KEY-TRACKING-GUIDE.md](./ACCESS-KEY-TRACKING-GUIDE.md)** - دليل شامل بالعربي
2. **[QUERY-EXAMPLES.md](./QUERY-EXAMPLES.md)** - أمثلة Queries متقدمة
3. **[grafana-cloudtrail-dashboard.json](./grafana-cloudtrail-dashboard.json)** - الـ Dashboard JSON

## 🔐 Security Best Practices

### Daily Monitoring
1. راجع Panel 4 يومياً للـ Failed Actions
2. راقب Panel 3 للنشاط الغير عادي
3. تحقق من Panel 5 للـ Suspicious IPs

### Weekly Review
1. راجع Panel 1 لمعرفة الـ Access patterns
2. تحقق من Panel 2 للـ Resource access
3. راجع Panels 6 & 7 للـ Infrastructure changes

### Monthly Audit
1. استخدم Panel 5 لتوليد Audit report
2. راجع كل الـ Access Keys
3. احذف الـ Unused keys

## 🐛 Troubleshooting

### Panel فاضي؟
```
1. تأكد إن CloudTrail logs بتوصل لـ Loki
   Query: {job="cloudtrail"} | limit 10

2. تأكد إن الـ Labels موجودة
   Query: {job="cloudtrail"} | json | line_format "{{.access_key_id}}"

3. تأكد إن الـ Time range صح
```

### البيانات مش دقيقة؟
```
1. راجع الـ Promtail config
2. تأكد إن الـ Python script شغال صح
3. تحقق من الـ S3 bucket permissions
```

### Performance بطيء؟
```
1. قلل الـ Time range
2. استخدم الـ Variables للتصفية
3. زود الـ Refresh interval من 30s لـ 1m
```

## 🎯 Next Steps

1. ✅ Import الـ Dashboard
2. ✅ Test الـ Panels
3. ✅ Configure Variables
4. 🔲 Set up Alerts
5. 🔲 Create Custom Panels
6. 🔲 Share with Team

## 📞 Support

للأسئلة أو المشاكل:
1. راجع [ACCESS-KEY-TRACKING-GUIDE.md](./ACCESS-KEY-TRACKING-GUIDE.md)
2. راجع [QUERY-EXAMPLES.md](./QUERY-EXAMPLES.md)
3. تحقق من الـ Loki logs

## 📝 Changelog

### Version 2.0 (2026-02-03)
- ✨ Added 7 new panels for Access Key tracking
- ✨ Added Resource access audit panels
- ✨ Added detailed activity log
- ✨ Added EC2 and S3 specific panels
- 📚 Added comprehensive documentation
- 📚 Added 50+ new query examples

### Version 1.0 (Previous)
- Initial dashboard with basic CloudTrail monitoring
- Event timeline
- Failed events tracking
- Basic statistics

---

**Made with ❤️ for AWS CloudTrail Monitoring**
