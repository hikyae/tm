#!/usr/bin/env python3
import datetime
import os
import re
import subprocess
import sys
import threading
import time

import numpy as np

# hide pygame startup message
os.environ["PYGAME_HIDE_SUPPORT_PROMPT"] = "hide"
import tkinter as tk
from tkinter import font as tkfont

import pygame

BLACK = "#000000"
GREEN = "#00ff00"
SAMPLE_RATE = 44100
BAR_HEIGHT = 65  # height of taskbar


def parse_time(timestr) -> float:
    if ":" in timestr:
        # HH:MM[:SS] format
        parts = list(map(int, timestr.split(":")))
        if len(parts) == 2:
            h, m = parts
            s = 0
        elif len(parts) == 3:
            h, m, s = parts
        else:
            raise ValueError("Invalid time format. Use HH:MM[:SS]")
        now = datetime.datetime.now()
        target = now.replace(hour=h, minute=m, second=s, microsecond=0)
        if target < now:
            target += datetime.timedelta(days=1)
        return target.timestamp()
    else:
        # 12h34m56s format
        match = re.fullmatch(r"(?:(\d+)h)?(?:(\d+)m)?(?:(\d+)s)?", timestr)
        if not match:
            raise ValueError("Invalid duration format. Use [12h][34m][56s]")
        h, m, s = (int(x) if x else 0 for x in match.groups())
        return time.time() + h * 3600 + m * 60 + s


class BaseWindow:
    """
    Responsible for displaying a simple centered Tkinter window with a message,
    handling user acknowledgement via click or key, and closing when acknowledged.
    """

    def __init__(self, message: str, title: str):
        self.message = message
        self.root = tk.Tk()
        self.root.title(title)
        self.root.configure(bg=BLACK)
        self.root.attributes("-topmost", True)
        self.root.resizable(False, False)

        msg_font = tkfont.Font(
            family="Cica, Noto Sans CJK JP, Meiryo UI, Yu Gothic UI",
            size=20,
            weight="normal",
        )
        self.label = tk.Label(
            self.root,
            text=message,
            font=msg_font,
            fg=GREEN,
            bg=BLACK,
            wraplength=1500,
            justify="center",
        )
        self.label.pack(padx=10, pady=0)

        self.acknowledged = False
        self.shown_at = time.time()

        self.label.bind("<Button-1>", self.on_ack)
        self.root.bind("<Button-1>", self.on_ack)
        self.root.bind("<Key>", self.on_key)

    def start(self):
        self.center_window()
        self.check_ack_loop()
        self.root.mainloop()

    def center_window(self):
        self.root.update_idletasks()
        w = self.root.winfo_width()
        h = self.root.winfo_height()
        sw = self.root.winfo_screenwidth()
        sh = self.root.winfo_screenheight()
        x = (sw - w) // 2
        y = (sh - h) // 2
        self.root.geometry(f"{w}x{h}+{x}+{y}")

    def on_ack(self, event=None):
        if time.time() - self.shown_at >= 0.5:
            self.acknowledged = True

    def on_key(self, event):
        if event.keysym in ("Return", "Escape", "space"):
            self.on_ack()

    def check_ack_loop(self):
        if self.acknowledged:
            self.on_acknowledged()
        else:
            self.root.after(100, self.check_ack_loop)

    def on_acknowledged(self):
        self.root.destroy()


class BeepPlayer:
    """
    Responsible for generating and playing a repeating beep sound until stopped.
    """

    def __init__(self, freq=2000, duration=0.3, sample_rate=SAMPLE_RATE, volume=0.8):
        pygame.mixer.init(frequency=sample_rate, size=-16, channels=2)
        self.freq = freq
        self.duration = duration
        self.sample_rate = sample_rate
        self.volume = volume
        self.stop_event = threading.Event()
        self.thread = threading.Thread(target=self._beep_loop, daemon=True)

    def _generate_beep_sound(self):
        t = np.linspace(
            0, self.duration, int(self.sample_rate * self.duration), endpoint=False
        )
        waveform = np.sin(2 * np.pi * self.freq * t) * self.volume
        waveform_integers = np.int16(waveform * 32767)
        stereo_waveform = np.column_stack((waveform_integers, waveform_integers))
        return pygame.sndarray.make_sound(stereo_waveform)

    def _beep_loop(self):
        sound = self._generate_beep_sound()
        while not self.stop_event.is_set():
            sound.play()
            time.sleep(0.5)

    def start(self):
        self.thread.start()

    def stop(self):
        self.stop_event.set()
        # thread is daemon; join briefly if possible
        self.thread.join(timeout=0.1)


class ErrorWindow(BaseWindow):
    """Specialized window for error messages; does not include sound."""

    def __init__(self, message):
        super().__init__(
            message,
            title="Error! Press Enter, Esc, or Space, or click the message to close.",
        )
        self.start()


class AlertWindow(BaseWindow):
    """Alert window that shows a message and plays a beep until acknowledged."""

    def __init__(self, message):
        super().__init__(message, title="Time is up")
        self.beep_player = BeepPlayer()
        self.beep_player.start()
        self.start()

    def on_acknowledged(self):
        self.beep_player.stop()
        super().on_acknowledged()


class TimerGUI:
    """
    Countdown timer display placed at bottom-right. When the timer expires,
    it invokes AlertWindow with the provided message.
    """

    def __init__(self, target_time, message):
        self.target_time = target_time
        self.message = message
        self.sway_sock: str | None = os.getenv("SWAYSOCK")

        if self.sway_sock:
            try:
                cmd = 'no_focus [workspace="__focused__" class="Tk" title="^Timer$"]'
                subprocess.run(["swaymsg", cmd], check=True, capture_output=True)
            except subprocess.CalledProcessError as e:
                print(e)
                pass

        self.root = tk.Tk()
        self.root.title("Timer")
        self.root.configure(bg=BLACK)
        self.root.attributes("-topmost", True)
        self.root.resizable(False, False)

        time_font = tkfont.Font(
            family="Cica, Noto Sans CJK JP, Meiryo UI, Yu Gothic UI", size=17
        )
        self.label = tk.Label(self.root, text="", font=time_font, fg=GREEN, bg=BLACK)
        self.label.pack(padx=10, pady=5)

        self.update_clock()
        self.place_bottom_right()
        self.root.mainloop()

    def place_bottom_right(self):
        self.root.update_idletasks()
        w = self.root.winfo_width()
        h = self.root.winfo_height()
        sw = self.root.winfo_screenwidth()
        sh = self.root.winfo_screenheight()
        # offset a bit from edges
        x = sw - w - 8
        y = sh - h - BAR_HEIGHT
        if self.sway_sock:
            try:
                cmd = f'[workspace="__focused__" class="Tk" title="^Timer$"] floating enable, move position {x} {y}'
                subprocess.run(["swaymsg", cmd], check=True, capture_output=True)
                return
            except subprocess.CalledProcessError as e:
                print(e)
                pass
        self.root.geometry(f"{w}x{h}+{x}+{y}")
        self.root.update_idletasks()

    def update_clock(self):
        remaining = self.target_time - time.time()
        if remaining > 0:
            rem_int = int(remaining + 1)
            hrs = rem_int // 3600
            mins = (rem_int % 3600) // 60
            secs = rem_int % 60
            time_str = f"{hrs:02}:{mins:02}:{secs:02}"
            last_time_str = self.label.cget("text")
            if time_str != last_time_str:
                self.label.config(text=time_str)
                if len(time_str) != len(last_time_str):
                    # fix position when window width changes
                    self.place_bottom_right()
            self.root.after(100, self.update_clock)
        else:
            self.root.destroy()
            AlertWindow(self.message)


def main():
    if len(sys.argv) < 3:
        mes = "Usage: tm HH:MM[:SS] message"
        print(mes)
        ErrorWindow(mes)
        return

    try:
        target_time = parse_time(sys.argv[1])
    except Exception as e:
        mes = f"Invalid time string: {e}"
        print(mes)
        ErrorWindow(mes)
        return

    message = " ".join(sys.argv[2:])
    TimerGUI(target_time, message)


if __name__ == "__main__":
    main()
