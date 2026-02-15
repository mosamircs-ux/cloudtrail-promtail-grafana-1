# 🚀 Quick Fix - Dashboard "No Data"

## المشكلة
Dashboard بيقول "No data" في معظم الـ Panels

---

## ✅ الحل السريع (5 دقائق)

### الخطوة 1: شغل الـ Diagnostic Script
```bash
cd /path/to/cloudtrail-promtail-setup
chmod +x diagnose-dashboard.sh
./diagnose-dashboard.sh
```

**النتيجة**: هيعرضلك المشاكل بالظبط

---

### الخطوة 2: الحلول الشائعة

#### الحل 1: Restart Services (الأكثر شيوعاً)
```bash
sudo systemctl restart cloudtrail-processor
sudo systemctl restart promtail

# انتظر دقيقتين
sleep 120

# افحص الـ logs
tail -f /var/log/cloudtrail/cloudtrail-*.json
```

#### الحل 2: تأكد من الـ Services شغالة
```bash
# CloudTrail Processor
sudo systemctl status cloudtrail-processor
sudo systemctl enable cloudtrail-processor
sudo systemctl start cloudtrail-processor

# Promtail
sudo systemctl status promtail
sudo systemctl enable promtail
sudo systemctl start promtail
```

#### الحل 3: افحص الـ Logs
```bash
# تأكد إن الـ logs بتتكتب
ls -lh /var/log/cloudtrail/

# شوف آخر log
tail -20 /var/log/cloudtrail/cloudtrail-$(date +%Y-%m-%d).json

# لو مفيش ملفات
sudo mkdir -p /var/log/cloudtrail
sudo chown cloudtrail:cloudtrail /var/log/cloudtrail
```

---

### الخطوة 3: Test في Grafana

#### 1. افتح Grafana Explore
```
Grafana → Explore (أيقونة البوصلة)
```

#### 2. اختار Loki Data Source
```
Data source: Loki
```

#### 3. جرب Query بسيط
```logql
{job="cloudtrail"}
```

**النتيجة المتوقعة**:
- ✅ لو ظهرت logs → الـ data موجود، المشكلة في الـ Dashboard
- ❌ لو "No data" → المشكلة في الـ Pipeline

---

### الخطوة 4: لو لسه "No data" في Explore

#### افحص Promtail Config
```bash
sudo cat /etc/promtail/promtail-cloudtrail-config.yml
```

**تأكد من**:
```yaml
clients:
  - url: http://localhost:3100/loki/api/v1/push
    # أو
  - url: http://YOUR_LOKI_SERVER:3100/loki/api/v1/push

scrape_configs:
  - job_name: cloudtrail
    static_configs:
      - targets:
          - localhost
        labels:
          job: cloudtrail
          __path__: /var/log/cloudtrail/*.json
```

**لو الـ URL غلط**:
```bash
sudo nano /etc/promtail/promtail-cloudtrail-config.yml
# عدل الـ URL
# Ctrl+X → Y → Enter

sudo systemctl restart promtail
```

---

### الخطوة 5: افحص CloudTrail Processor

```bash
# شوف الـ logs
sudo journalctl -u cloudtrail-processor -n 50

# لازم تشوف حاجة زي:
# "Processing file from S3: ..."
# "Downloaded CloudTrail file: ..."
# "Processed X events"
```

**لو مفيش logs**:
```bash
# افحص الـ config
cat /path/to/config.yaml

# تأكد من:
# 1. S3 bucket name صحيح
# 2. AWS region صحيح
# 3. IAM permissions موجودة
```

---

## 🎯 الحلول حسب الـ Error Message

### Error: "Cannot visualize data"
**السبب**: الـ transformation في الـ panel غلط

**الحل**:
```bash
# في الـ Panel → Edit
# شوف الـ Transformations
# تأكد إن الـ field names صحيحة
```

### Error: "No data"
**السبب**: مفيش data في Loki للـ query ده

**الحل**:
```bash
# 1. Test الـ query في Explore
# 2. جرب query أبسط: {job="cloudtrail"}
# 3. لو ظهرت data، المشكلة في الـ query
# 4. لو مفيش data، المشكلة في الـ pipeline
```

### Error: "Loki: 404 Not Found"
**السبب**: Loki URL غلط

**الحل**:
```bash
# في Grafana → Configuration → Data Sources → Loki
# تأكد من الـ URL:
# http://localhost:3100
# أو
# http://YOUR_LOKI_SERVER:3100
```

---

## 📋 Quick Checklist

```bash
# على الـ EC2 instance:

# 1. Services شغالة؟
sudo systemctl status cloudtrail-processor
sudo systemctl status promtail

# 2. Log files موجودة؟
ls -lh /var/log/cloudtrail/

# 3. Logs بتتحدث؟
tail -f /var/log/cloudtrail/cloudtrail-*.json

# 4. Promtail بيشحن؟
sudo journalctl -u promtail -f | grep "Successfully sent batch"

# 5. في Grafana Explore:
{job="cloudtrail"}
```

---

## 🔧 One-Liner Fix (جرب ده الأول!)

```bash
sudo systemctl restart cloudtrail-processor promtail && sleep 120 && tail -20 /var/log/cloudtrail/cloudtrail-$(date +%Y-%m-%d).json
```

**ده هيعمل**:
1. Restart الـ services
2. ينتظر دقيقتين
3. يعرض آخر 20 log entry

---

## 💡 لو كل حاجة شغالة بس لسه "No data"

### المشكلة المحتملة: Time Range

```bash
# في الـ Dashboard
# أعلى اليمين → Time Range
# غيره لـ:
- Last 24 hours
- Last 7 days
```

**السبب**: لو الـ CloudTrail logs قديمة والـ time range = Last 6 hours

---

## 📞 لو لسه محتاج مساعدة

### افحص كل حاجة:
```bash
# 1. Run diagnostic script
./diagnose-dashboard.sh

# 2. افحص الـ full logs
sudo journalctl -u cloudtrail-processor -n 100 > processor.log
sudo journalctl -u promtail -n 100 > promtail.log

# 3. شوف الـ logs
cat processor.log
cat promtail.log

# 4. شارك الـ logs للمساعدة
```

---

## ✅ بعد الحل

```bash
# 1. Refresh الـ Dashboard
# 2. اختار Time Range مناسب (Last 24h)
# 3. شوف الـ Panels واحد واحد
# 4. لو في panel معين "No data":
#    - Edit Panel
#    - شوف الـ Query
#    - Test في Explore
```

---

## 🎉 Success!

لما الـ data تبدأ تظهر:
- ✅ Dashboard بيعرض data
- ✅ Panels بتتحدث
- ✅ Drill-down شغال
- ✅ Filters شغالة

**استمتع بالمراقبة! 🚀**
