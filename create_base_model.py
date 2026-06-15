import os
import subprocess

tables = [
      "RAW_RAVENSTACK_ACCOUNTS",
      "RAW_RAVENSTACK_CHURN_EVENTS", 
      "RAW_RAVENSTACK_FEATURE_USAGE", 
      "RAW_RAVENSTACK_SUBSCRIPTIONS",
      "RAW_RAVENSTACK_SUPPORT_TICKETS", 
]

target_dir = "models/staging"
os.makedirs(target_dir, exist_ok=True)

for table in tables:
    file_name = f"STG_{table}.sql"
    file_path = os.path.join(target_dir, file_name)

    cmd = f"dbt run-operation generate_base_model --args '{{\"source_name\": \"revenstack\", \"table_name\": \"{table}\"}}'"
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)

    lines = result.stdout.split("\n")
    
    sql_content = []
    start_collecting = False

    for line in lines:
        if "with source as (" in line or "with source as" in line:
            start_collecting = True
        if start_collecting:
            if line.strip():
                sql_content.append(line)
        if line.endswith('renamed'):
            break

    if sql_content:
        with open(file_path, "w") as f:
            f.write("\n".join(sql_content))
        print(f"      ✅ -> Successfully created {table} PATH: {file_path}")
    else:
        print(f"      ❌ -> Failed at creating TABLE: {table}")

print('Finished Table Creation')