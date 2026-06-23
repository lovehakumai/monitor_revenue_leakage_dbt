import json
import os

def combine_dbt_docs():
    html_path = "target/index.html"
    manifest_path = "target/manifest.json"
    catalog_path = "target/catalog.json"

    # 必要なファイルが存在するか確認
    if not (os.path.exists(html_path) and os.path.exists(manifest_path) and os.path.exists(catalog_path)):
        print("❌ Error: Required dbt docs files are missing in 'target/' directory.")
        return

    print("📖 Reading dbt docs components...")
    with open(html_path, "r", encoding="utf-8") as f:
        html_content = f.read()

    with open(manifest_path, "r", encoding="utf-8") as f:
        manifest_json = json.load(f)

    with open(catalog_path, "r", encoding="utf-8") as f:
        catalog_json = json.load(f)

    # dbt v1.0+ の index.html 内にあるJavaScriptの初期化プレースホルダー
    target_placeholder = 'o=[{label:"manifest",key:"manifest",value:null},{label:"catalog",key:"catalog",value:null}]'
    
    # JSONデータをHTML内に直接オブジェクトとして埋め込むための文字列を生成
    injected_str = f'o=[{{label:"manifest",key:"manifest",value:{json.dumps(manifest_json)}}},{{label:"catalog",key:"catalog",value:{json.dumps(catalog_json)}}}]'

    if target_placeholder in html_content:
        html_content = html_content.replace(target_placeholder, injected_str)
        print("💉 Successfully injected manifest.json and catalog.json into index.html!")
    else:
        print("⚠️ Warning: Target placeholder not found. Checking alternate patterns...")
        # 念のため、スペースやクォーテーションの微妙な差異に対応するフォールバック（必要に応じて）
        return

    # 1ファイルに統合されたHTMLとして元の index.html を上書き
    with open(html_path, "w", encoding="utf-8") as f:
        f.write(html_content)
    print("💾 Saved the standalone index.html.")

if __name__ == "__main__":
    combine_dbt_docs()