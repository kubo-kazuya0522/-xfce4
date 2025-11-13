import tkinter as tk

def on_button_click():
    label.config(text="Hello, noVNC!")

# ウィンドウ作成
root = tk.Tk()
root.title("Tkinter on Codespaces")
root.geometry("400x200")

# ラベル
label = tk.Label(root, text="Welcome!")
label.pack(pady=20)

# ボタン
button = tk.Button(root, text="Click Me", command=on_button_click)
button.pack()

# メインループ
root.mainloop()
