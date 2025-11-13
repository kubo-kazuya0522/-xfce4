import tkinter as tk

def on_button_click():
    label.config(text="Hello, noVNC!")

def change_label_text():
    user_input = entry.get()  # Entryウィジェットからテキストを取得
    label.config(text=f"Hello, {user_input}!")

def change_background_color():
    root.config(bg="lightblue")  # ウィンドウの背景色を変更

# ウィンドウ作成
root = tk.Tk()
root.title("Tkinter on Codespaces")
root.geometry("400x300")  # サイズ変更

# ラベル
label = tk.Label(root, text="Welcome!")
label.pack(pady=20)

# 入力フィールド（テキスト入力用）
entry = tk.Entry(root)
entry.pack(pady=10)

# ボタン1: "Click Me"
button = tk.Button(root, text="Click Me", command=on_button_click)
button.pack(pady=5)

# ボタン2: テキスト入力を反映
input_button = tk.Button(root, text="Set Label to Input", command=change_label_text)
input_button.pack(pady=5)

# ボタン3: 背景色を変更
bg_button = tk.Button(root, text="Change Background Color", command=change_background_color)
bg_button.pack(pady=5)

# メインループ
root.mainloop()
