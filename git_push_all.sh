#!/bin/bash
repos=(
  "."
  "core-layer"
  "admin-frontend/mitm_fe_cpp"
  "transformation-layer/mitm_transformation_main"
  "collector-layer/mitm_collector_employee_pg"
  "collector-layer/mitm_collector_ora"
  "collector-layer/mitm_collector_mft"
  "collector-layer/mitm_collector_csv-xls"
  "collector-layer/mitm_collector_kafka"
  "collector-layer/mitm_collector_employee-tmp-assigns_ora"
  "collector-layer/mitm_collector_employee_ora"
  "collector-layer/mitm_collector_pg"
  "maintenance-layer/mitm_key_rotation"
  "maintenance-layer/mitm_maintenance_config"
  "maintenance-layer/mitm_maintenance_cleanup"
  "maintenance-layer/mitm_adm-data-debug"
  "delivery-layer/mitm_delivery_cority"
  "delivery-layer/mitm_delivery_apigee"
)

for repo in "${repos[@]}"; do
  echo "======================================"
  echo "Processing: $repo"
  cd "$repo" || continue
  
  if [ -d ".git" ]; then
    # Check if there are changes
    if ! git diff --quiet || ! git diff --cached --quiet || [ -n "$(git ls-files --others --exclude-standard)" ]; then
      git add .
      git commit -m "chore(specdd): integrate specdd framework constraints, fix codebase alignment and implement zeroize/SPDX"
      git push
    else
      echo "No changes to commit in $repo"
    fi
  else
    echo "No .git directory found in $repo"
  fi
  
  cd - > /dev/null
done
