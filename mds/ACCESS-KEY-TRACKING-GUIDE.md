# Access Key and Resource Tracking - Dashboard Guide

## نظرة عامة (Overview)

تم إضافة 7 panels جديدة للـ Grafana Dashboard لتتبع استخدام Access Keys والـ Resources في AWS CloudTrail.

## الـ Panels الجديدة

### 1. Access Key → Resource Usage (ما الذي يستخدمه كل Access Key)
**الموقع**: Row 4, Left Panel  
**النوع**: Table  
**الوصف**: يعرض جدول يوضح كل Access Key وما هي الـ Resources/Actions التي يستخدمها

**الأعمدة**:
- Access Key: معرف الـ Access Key
- Resource/Action: اسم الـ Event/Resource المستخدم
- Count: عدد المرات التي تم فيها الاستخدام

**الاستخدام**: 
- اعرف كل Access Key بيعمل إيه
- حدد الـ Keys النشطة جداً
- اكتشف استخدامات غير متوقعة

---

### 2. Resource → Access Keys (مين عنده Access على كل Resource)
**الموقع**: Row 4, Right Panel  
**النوع**: Table  
**الوصف**: يعرض الـ Resources ومين الـ Access Keys اللي عندها صلاحية عليها

**الأعمدة**:
- Event Name: نوع الـ Resource/Action
- Access Key: الـ Access Key المستخدم
- Resources: تفاصيل الـ Resource

**الاستخدام**:
- اعرف مين عنده Access على resource معين
- راجع الصلاحيات
- اكتشف Access غير مصرح به

---

### 3. Access Key Activity Timeline (جدول زمني للاستخدام)
**الموقع**: Row 5, Full Width  
**النوع**: Time Series Graph  
**الوصف**: رسم بياني يوضح استخدام كل Access Key عبر الزمن

**المميزات**:
- خطوط ملونة لكل Access Key
- يعرض Sum و Last في الـ Legend
- Smooth interpolation للوضوح

**الاستخدام**:
- راقب patterns الاستخدام
- اكتشف نشاط غير عادي
- حدد أوقات الذروة

---

### 4. Access Key Consumption Summary (ملخص الاستهلاك)
**الموقع**: Row 6, Full Width  
**النوع**: Table with Gauges  
**الوصف**: جدول شامل يعرض إحصائيات كل Access Key

**الأعمدة**:
- Access Key ID: معرف الـ Key
- Total Actions: إجمالي العمليات (مع Gradient Gauge)
- Failed Actions: العمليات الفاشلة (باللون الأحمر)
- Unique Resources: عدد الـ Resources المختلفة

**الألوان**:
- أخضر: < 100 عملية
- أصفر: 100-500 عملية
- برتقالي: 500-1000 عملية
- أحمر: > 1000 عملية

**الاستخدام**:
- راجع استهلاك كل Key
- حدد الـ Keys المشبوهة (Failed Actions عالية)
- خطط للـ Capacity

---

### 5. Detailed Activity Log (سجل النشاط التفصيلي)
**الموقع**: Row 7, Full Width  
**النوع**: Table  
**الوصف**: جدول تفصيلي يعرض كل عملية بالتفصيل (مين عمل إيه وامتى وفين)

**الأعمدة**:
- Time: وقت العملية
- Access Key: الـ Access Key المستخدم
- Action: العملية المنفذة
- Resource: الـ Resource المستهدف
- User/Principal: المستخدم أو الـ Role
- Source IP: عنوان IP المصدر
- Region: الـ AWS Region
- Status: نجاح/فشل (بألوان)
- Error Code: كود الخطأ (إن وجد)
- Error Message: رسالة الخطأ

**المميزات**:
- Status بألوان (أخضر للنجاح، أحمر للفشل)
- مرتب حسب الوقت (الأحدث أولاً)
- يستخدم الـ Variable `$access_key` للتصفية

**الاستخدام**:
- تدقيق كامل للنشاط
- تحقيق في الحوادث
- Compliance reporting

---

### 6. EC2 Resources → Access Keys (تدقيق الوصول لـ EC2)
**الموقع**: Row 8, Left Panel  
**النوع**: Table  
**الوصف**: يعرض أي Access Keys وصلت لـ EC2 Instances

**الـ Events المتتبعة**:
- RunInstances
- StartInstances
- StopInstances
- TerminateInstances
- CreateVolume
- DeleteVolume

**الاستخدام**:
- راقب من يتحكم في الـ EC2 Instances
- اكتشف محاولات غير مصرح بها
- تدقيق التغييرات على الـ Infrastructure

---

### 7. S3 Resources → Access Keys (تدقيق الوصول لـ S3)
**الموقع**: Row 8, Right Panel  
**النوع**: Table  
**الوصف**: يعرض أي Access Keys وصلت لـ S3 Buckets

**الـ Events المتتبعة**:
- PutObject
- GetObject
- DeleteObject
- CreateBucket
- DeleteBucket

**الاستخدام**:
- راقب الوصول للبيانات
- اكتشف Data Exfiltration
- تدقيق تغييرات الـ S3

---

## الـ Variables المتاحة

الـ Dashboard يستخدم 3 variables للتصفية:

1. **$access_key**: تصفية حسب Access Key
2. **$event_name**: تصفية حسب Event Name
3. **$aws_region**: تصفية حسب AWS Region

---

## حالات الاستخدام الشائعة

### 1. تدقيق Access Key معين
1. اختر الـ Access Key من الـ Variable في الأعلى
2. شوف Panel 5 (Detailed Activity Log)
3. راجع كل العمليات بالتفصيل

### 2. معرفة مين وصل لـ Resource معين
1. روح لـ Panel 2 (Resource → Access Keys)
2. دور على الـ Resource في الجدول
3. شوف كل الـ Access Keys اللي وصلت له

### 3. اكتشاف Access Keys مشبوهة
1. شوف Panel 4 (Consumption Summary)
2. دور على Keys بـ Failed Actions عالية
3. راجع تفاصيلها في Panel 5

### 4. مراقبة EC2 Instance معين
1. روح لـ Panel 6 (EC2 Access Audit)
2. دور على الـ Instance ID
3. شوف مين عمل إيه عليه

### 5. تتبع استخدام Access Key عبر الزمن
1. شوف Panel 3 (Activity Timeline)
2. لاحظ الـ Patterns
3. اكتشف أي نشاط غير عادي

---

## نصائح للاستخدام الأمثل

### Performance
- استخدم Time Range مناسب (6h-24h للمراقبة اليومية)
- استخدم الـ Variables للتصفية وتقليل البيانات
- الـ Dashboard يتحدث تلقائياً كل 30 ثانية

### Security
- راجع Panel 4 يومياً للـ Failed Actions
- راقب Panel 3 للنشاط الغير عادي
- استخدم Panel 5 للتحقيق في الحوادث

### Compliance
- استخدم Panel 5 لتوليد Audit Reports
- Panel 6 و 7 للـ Resource-specific audits
- احفظ Screenshots للتوثيق

---

## Queries المستخدمة

### Panel 1 Query
```logql
sum by (access_key_id, event_name) (count_over_time({job="cloudtrail", access_key_id!="N/A"}[$__range]))
```

### Panel 2 Query
```logql
{job="cloudtrail"} | json | line_format "{{.event_name}}|||{{.access_key_id}}|||{{.resources}}"
```

### Panel 3 Query
```logql
sum by (access_key_id) (count_over_time({job="cloudtrail", access_key_id!="N/A"}[$__interval]))
```

### Panel 4 Queries
```logql
# Query A: Total Actions
sum by (access_key_id) (count_over_time({job="cloudtrail", access_key_id!="N/A"}[$__range]))

# Query B: Failed Actions
sum by (access_key_id) (count_over_time({job="cloudtrail", access_key_id!="N/A", success="false"}[$__range]))

# Query C: Unique Resources
count by (access_key_id) (count by (access_key_id, event_name) (count_over_time({job="cloudtrail", access_key_id!="N/A"}[$__range])))
```

### Panel 5 Query
```logql
{job="cloudtrail", access_key_id=~"$access_key"} | json
```

### Panel 6 Query
```logql
{job="cloudtrail", event_name=~"RunInstances|StartInstances|StopInstances|TerminateInstances|CreateVolume|DeleteVolume"} | json | line_format "{{.resources}}|||{{.access_key_id}}|||{{.event_name}}"
```

### Panel 7 Query
```logql
{job="cloudtrail", event_name=~"PutObject|GetObject|DeleteObject|CreateBucket|DeleteBucket"} | json | line_format "{{.resources}}|||{{.access_key_id}}|||{{.event_name}}"
```

---

## استكشاف الأخطاء

### لو Panel فاضي
1. تأكد إن CloudTrail Logs بتوصل لـ Loki
2. تأكد إن الـ Time Range صح
3. تأكد إن الـ Variables مش بتفلتر كل البيانات

### لو البيانات مش دقيقة
1. تأكد إن الـ Promtail config صح
2. راجع الـ Python script للـ log processing
3. تأكد إن الـ Labels بتتعمل صح

### لو Performance بطيء
1. قلل الـ Time Range
2. استخدم الـ Variables للتصفية
3. زود الـ Refresh interval

---

## الخطوات التالية

1. **Import الـ Dashboard**: استورد `grafana-cloudtrail-dashboard.json` في Grafana
2. **Configure Data Source**: تأكد إن Loki Data Source متكونفج صح
3. **Test**: جرب الـ Variables والـ Panels
4. **Customize**: عدل الـ Queries حسب احتياجاتك
5. **Set Alerts**: أضف Alerts على الـ Panels المهمة

---

## المراجع

- [QUERY-EXAMPLES.md](./QUERY-EXAMPLES.md) - أمثلة Queries إضافية
- [Loki Query Language](https://grafana.com/docs/loki/latest/logql/) - Documentation
- [CloudTrail Events](https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-event-reference.html) - AWS Docs
