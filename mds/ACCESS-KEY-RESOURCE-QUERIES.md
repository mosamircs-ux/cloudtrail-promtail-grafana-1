# CloudTrail Queries: Filter by Access Key and Resource

## 🎯 الهدف
دليل شامل لعمل queries في Grafana لتتبع Access Key معين وشوف عمل access على أنهي Resources.

---

## 📋 الـ Queries الأساسية

### 1. كل الـ Events لـ Access Key معين
```logql
{job="cloudtrail", access_key_id="AKIA..."}
```
**الاستخدام:** غيّر `AKIA...` بالـ Access Key اللي عايزه

---

### 2. شوف الـ Resources اللي الـ Access Key وصلها
```logql
{job="cloudtrail", access_key_id="AKIA..."} 
| json 
| line_format "{{.timestamp}} | {{.event_name}} | {{.resources}}"
```
**النتيجة:** هيعرضلك الوقت، الـ Event، والـ Resource

---

### 3. عدد الـ Events لكل Resource
```logql
sum by (resources) (count_over_time({job="cloudtrail", access_key_id="AKIA..."}[24h]))
```
**النتيجة:** عدد المرات اللي الـ Access Key وصل لكل Resource

---

### 4. Table بكل التفاصيل (Access Key + Resource + Event)
```logql
{job="cloudtrail", access_key_id="AKIA..."} | json
```
**في Grafana:**
1. استخدم الـ query ده
2. في **Transformations** → اختار **Extract fields** → **JSON**
3. هيعرضلك table فيها كل الـ fields

---

## 🔍 Queries متقدمة

### 5. فلتر بـ Access Key + Resource معين
```logql
{job="cloudtrail", access_key_id="AKIA..."} 
| json 
| resources =~ ".*arn:aws:s3:::my-bucket.*"
```
**الاستخدام:** غيّر `my-bucket` باسم الـ Resource اللي عايزه

---

### 6. شوف كل الـ S3 Resources اللي Access Key وصلها
```logql
{job="cloudtrail", access_key_id="AKIA..."} 
| json 
| resources =~ ".*arn:aws:s3:::.*"
| line_format "{{.event_name}} → {{.resources}}"
```

---

### 7. شوف كل الـ EC2 Instances اللي Access Key وصلها
```logql
{job="cloudtrail", access_key_id="AKIA..."} 
| json 
| resources =~ ".*arn:aws:ec2:.*:instance/.*"
| line_format "{{.event_name}} → {{.resources}}"
```

---

### 8. شوف Failed Events على Resource معين
```logql
{job="cloudtrail", access_key_id="AKIA...", success="false"} 
| json 
| resources =~ ".*my-resource.*"
| line_format "❌ {{.event_name}} on {{.resources}} - Error: {{.error_code}}"
```

---

## 📊 Queries للـ Dashboard Panels

### Panel 1: Table - Access Key Activity with Resources
```logql
{job="cloudtrail", access_key_id=~"$access_key"} | json
```
**Transformations:**
1. Extract fields (JSON)
2. Organize columns:
   - timestamp
   - access_key_id
   - event_name
   - resources
   - aws_region
   - success

---

### Panel 2: Pie Chart - Resources by Access Count
```logql
sum by (resources) (count_over_time({job="cloudtrail", access_key_id=~"$access_key"}[$__range]))
```

---

### Panel 3: Bar Chart - Events per Resource
```logql
sum by (resources, event_name) (count_over_time({job="cloudtrail", access_key_id=~"$access_key"}[$__range]))
```

---

### Panel 4: Table - Top 10 Most Accessed Resources
```logql
{job="cloudtrail", access_key_id=~"$access_key"} | json
```
**Transformations:**
1. Extract fields (JSON)
2. Group by `resources`
3. Aggregate: Count
4. Sort by Count (descending)
5. Limit: 10

---

## 🎨 إضافة Panel جديد في Dashboard

### الخطوات:

1. **افتح Dashboard** في Grafana
2. اضغط **Add Panel**
3. اختار **Table** أو **Pie Chart**
4. في **Query**، استخدم واحد من الـ queries فوق
5. في **Panel Title**، حط: `📦 Resources by Access Key`
6. **Save**

---

## 🔧 استخدام Variables (Filters)

### في Dashboard Settings → Variables:

#### Variable 1: Access Key
```
Name: access_key
Label: Access Key
Query: label_values({job="cloudtrail"}, access_key_id)
Multi-value: Yes
Include All: Yes
```

#### Variable 2: Event Name (اختياري)
```
Name: event_name
Label: Event Name
Query: label_values({job="cloudtrail", access_key_id=~"$access_key"}, event_name)
Multi-value: Yes
Include All: Yes
```

---

## 💡 أمثلة عملية

### مثال 1: شوف كل الـ S3 GetObject events لـ Access Key معين
```logql
{job="cloudtrail", access_key_id="AKIAIOSFODNN7EXAMPLE", event_name="GetObject"} 
| json 
| resources =~ ".*arn:aws:s3:::.*"
| line_format "{{.timestamp}} | {{.resources}} | IP: {{.source_ip}}"
```

---

### مثال 2: شوف أكثر 5 Resources تم الوصول ليها
```logql
topk(5, sum by (resources) (count_over_time({job="cloudtrail", access_key_id="AKIA..."}[7d])))
```

---

### مثال 3: شوف الـ Access Key عمل إيه على EC2 Instance معين
```logql
{job="cloudtrail", access_key_id="AKIA..."} 
| json 
| resources =~ ".*i-1234567890abcdef0.*"
| line_format "{{.timestamp}} | {{.event_name}} | Success: {{.success}}"
```

---

### مثال 4: شوف كل الـ Failed attempts على Resource معين
```logql
{job="cloudtrail", success="false"} 
| json 
| resources =~ ".*my-important-resource.*"
| line_format "❌ {{.access_key_id}} tried {{.event_name}} - Error: {{.error_code}}"
```

---

## 📈 Dashboard Panel Recommendations

### Panel 1: **Access Key → Resources Table**
- **Type:** Table
- **Query:** `{job="cloudtrail", access_key_id=~"$access_key"} | json`
- **Columns:** Time, Access Key, Event, Resources, Region, Status
- **Sort by:** Time (descending)

### Panel 2: **Top Resources Pie Chart**
- **Type:** Pie Chart
- **Query:** `sum by (resources) (count_over_time({job="cloudtrail", access_key_id=~"$access_key"}[$__range]))`
- **Legend:** Right side, show values

### Panel 3: **Event Timeline**
- **Type:** Time Series
- **Query:** `sum by (event_name) (count_over_time({job="cloudtrail", access_key_id=~"$access_key"}[$__interval]))`
- **Display:** Bars, stacked

### Panel 4: **Failed Access Attempts**
- **Type:** Table
- **Query:** `{job="cloudtrail", access_key_id=~"$access_key", success="false"} | json`
- **Highlight:** Error codes in red

---

## 🚀 Quick Start

### للبدء السريع:

1. افتح **Grafana** → **Explore**
2. اختار **Loki** data source
3. استخدم Query:
   ```logql
   {job="cloudtrail", access_key_id="AKIA..."} | json | line_format "{{.event_name}} → {{.resources}}"
   ```
4. غيّر `AKIA...` بالـ Access Key بتاعك
5. اضغط **Run Query**

---

## 📝 ملاحظات مهمة

1. **Resources هو Array** - كل event ممكن يكون ليه أكثر من resource
2. **استخدم Regex** - للبحث في الـ resources استخدم `=~` مش `=`
3. **الـ Variables** - استخدم `$access_key` في الـ queries عشان تقدر تفلتر من الـ Dashboard
4. **Time Range** - غيّر الـ time range حسب احتياجك (Last 6h, Last 24h, Last 7d)

---

## 🎯 الخلاصة

**للإجابة على سؤالك:**
> "عايز لما اختار access key كأنه filter access key يجيبلي resource"

**الحل:**
1. استخدم الـ query: `{job="cloudtrail", access_key_id=~"$access_key"} | json`
2. عمل Table panel
3. اعرض column اسمه `resources`
4. استخدم الـ Access Key variable في الفلتر فوق

**النتيجة:** لما تختار Access Key من الفلتر، الـ table هيعرضلك كل الـ Resources اللي الـ Access Key ده وصلها! ✅

---

**جرب الـ queries دي في Grafana Explore وقولي النتيجة!** 🚀
