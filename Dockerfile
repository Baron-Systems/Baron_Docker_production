FROM frappe/bench:latest

# ====== المتغيرات القادمة من docker-compose (.env) ======
ARG FRAPPE_BRANCH
ARG ERPNEXT_REPO
ARG ERPNEXT_BRANCH
ARG BARONAPP_REPO
ARG BARONAPP_BRANCH

# IMPORTANT:
# لا نريد system redis داخل الصورة (سيكون عندنا redis كخدمة منفصلة في docker-compose)
# لذلك لا نثبت redis-server هنا.

# نضمن أننا نشتغل بمستخدم frappe (موجود مسبقًا في frappe/bench)
USER frappe

# نستخدم /workspace كدليل العمل الرئيسي
WORKDIR /workspace

# ====== إنشاء bench جديد داخل /workspace/frappe-bench وتنزيل ERPNext (+ baron app لو موجود) ======
RUN bench init \
      --frappe-branch "${FRAPPE_BRANCH}" \
      --skip-assets \
      --skip-redis-config-generation \
      frappe-bench \
    && cd frappe-bench \
    # تنزيل ERPNext
    && bench get-app --branch "${ERPNEXT_BRANCH}" "${ERPNEXT_REPO}" \
    # تنزيل تطبيق مخصص (baron app) لو BARONAPP_REPO غير فارغ
    && if [ -n "${BARONAPP_REPO}" ]; then \
         bench get-app --branch "${BARONAPP_BRANCH}" baronapp "${BARONAPP_REPO}"; \
       fi \
    # common_site_config.json مبدئيًا فارغ، لاحقًا يتعدل من داخل الكونتينر
    && echo "{}" > sites/common_site_config.json

# الـ bench الحقيقي هنا
WORKDIR /workspace/frappe-bench

# Volumes للـ sites والـ logs (والـ assets داخل sites)
# هذه لازم تطابق المسارات في docker-compose.yml
VOLUME [ \
  "/workspace/frappe-bench/sites", \
  "/workspace/frappe-bench/logs", \
  "/workspace/frappe-bench/sites/assets" \
]

# المنفذ اللي بيشتغل عليه gunicorn داخل الكونتينر
EXPOSE 8000

# ====== CMD الافتراضي (Production Backend) ======
# هذا ال CMD هو اللي نستخدمه في خدمة backend في docker-compose:
# baron-erp-backend → gunicorn (PROD)
CMD [ \
  "/workspace/frappe-bench/env/bin/gunicorn", \
  "--chdir=/workspace/frappe-bench/sites", \
  "--bind=0.0.0.0:8000", \
  "--threads=4", \
  "--workers=2", \
  "--worker-class=gthread", \
  "--worker-tmp-dir=/dev/shm", \
  "--timeout=120", \
  "--preload", \
  "frappe.app:application" \
]
