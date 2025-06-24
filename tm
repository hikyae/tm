#!/usr/bin/env python3
import datetime
import os
import re
import sys
import threading
import time

import numpy as np

os.environ["PYGAME_HIDE_SUPPORT_PROMPT"] = "hide"
import pygame

BLACK = (0, 0, 0)
GREEN = (0, 255, 0)
SAMPLE_RATE = 44100


def generate_beep_sound(
    freq=2000,
    duration=0.3,
    sample_rate=SAMPLE_RATE,
    volume=0.8,
):
    t = np.linspace(0, duration, int(sample_rate * duration), endpoint=False)
    waveform = np.sin(2 * np.pi * freq * t) * volume
    waveform_integers = np.int16(waveform * 32767)
    stereo_waveform = np.column_stack((waveform_integers, waveform_integers))
    return pygame.sndarray.make_sound(stereo_waveform)


def beep_loop(stop_event):
    sound = generate_beep_sound()
    while not stop_event.is_set():
        sound.play()
        time.sleep(0.5)


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
        h, m, s = (int(m) if m else 0 for m in match.groups())
        return time.time() + h * 3600 + m * 60 + s


def get_center_rect(screen, img):
    rect = img.get_rect()
    rect.center = (screen.get_width() // 2, screen.get_height() // 2)
    return rect


class TimerGUI:
    def __init__(self, target_time, message):
        self.target_time = target_time
        self.message = message

        pygame.mixer.init(frequency=SAMPLE_RATE, size=-16, channels=2)
        pygame.init()

        pygame.display.set_caption("Timer")
        self.screen = pygame.display.set_mode((100, 50))
        self.time_font = pygame.font.SysFont(None, 28)
        self.msg_font = pygame.font.SysFont(
            ("Cica", "Noto Sans CJK JP", "Meiryo UI", "Yu Gothic UI"), 30
        )
        self.msg_rect = pygame.Rect(0, 0, 0, 0)

    def update_clock(self, remaining):
        rem_int = int(remaining + 1)
        hrs = rem_int // 3600
        mins = (rem_int % 3600) // 60
        secs = rem_int % 60
        time_str = f"{hrs:02}:{mins:02}:{secs:02}"
        time_img = self.time_font.render(time_str, True, GREEN)
        self.screen.blit(time_img, get_center_rect(self.screen, time_img))
        pygame.display.update()

    def show_time_is_up(self):
        msg_img = self.msg_font.render(self.message, True, GREEN)
        pygame.display.set_caption("Time is up")
        self.screen = pygame.display.set_mode((msg_img.get_width() + 20, 50))
        self.msg_rect = get_center_rect(self.screen, msg_img)
        self.screen.blit(msg_img, self.msg_rect)
        pygame.display.update()

    def beep_start(self, stop_event):
        self.beep_thread = threading.Thread(target=beep_loop, args=(stop_event,))
        self.beep_thread.start()

    def beep_stop(self, stop_event):
        stop_event.set()
        if self.beep_thread:
            self.beep_thread.join()

    def alert_acknowledged(self, event) -> bool:
        # Return True if the alert was acknowledged by any of the following actions
        # 1. Message area was clicked
        # 2. Enter key was pressed
        # 3. Esc key was pressed
        # 4. Space key was pressed
        return (
            event.type == pygame.MOUSEBUTTONDOWN
            and self.msg_rect.collidepoint(event.pos)
            or event.type == pygame.KEYDOWN
            and event.key
            in (
                pygame.K_RETURN,
                pygame.K_ESCAPE,
                pygame.K_SPACE,
            )
        )

    def run(self):
        running = True
        counting_down = True
        stop_event = threading.Event()
        while running:
            remaining = self.target_time - time.time()
            self.screen.fill(BLACK)

            if counting_down:
                self.update_clock(remaining)

                if remaining <= 0:
                    counting_down = False
                    self.beep_start(stop_event)
                    self.show_time_is_up()

            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    running = False
                elif remaining <= -0.5 and self.alert_acknowledged(event):
                    # Ignore any action and keep showing the message for at least 0.5 seconds.
                    # This prevents the message from disappearing if the user accidentally presses
                    # some keys while typing.
                    self.beep_stop(stop_event)
                    running = False

            time.sleep(0.1)

        pygame.quit()


class ErrorGUI:
    def __init__(self, message):
        self.message = message

        pygame.init()

    def show(self):
        pygame.display.set_caption(
            "Error! Press Enter, Esc, or Space, or click the message to close."
        )
        msg_font = pygame.font.SysFont(("Cica", "Noto Sans CJK JP"), 30)
        msg_img = msg_font.render(self.message, True, GREEN)
        screen = pygame.display.set_mode((msg_img.get_width() + 20, 50))
        self.msg_rect = get_center_rect(screen, msg_img)
        screen.blit(msg_img, self.msg_rect)
        pygame.display.update()

    def error_acknowledged(self, event) -> bool:
        # Return True if the alert was acknowledged by any of the following actions
        # 1. Message area was clicked
        # 2. Enter key was pressed
        # 3. Esc key was pressed
        # 4. Space key was pressed
        return (
            event.type == pygame.MOUSEBUTTONDOWN
            and self.msg_rect.collidepoint(event.pos)
            or event.type == pygame.KEYDOWN
            and event.key
            in (
                pygame.K_RETURN,
                pygame.K_ESCAPE,
                pygame.K_SPACE,
            )
        )

    def run(self):
        self.show()
        running = True
        while running:
            for event in pygame.event.get():
                if event.type == pygame.QUIT or self.error_acknowledged(event):
                    running = False

            time.sleep(0.1)

        pygame.quit()


def main():
    if len(sys.argv) < 3:
        mes = "Usage: tm HH:MM[:SS] message"
        print(mes)
        error_gui = ErrorGUI(mes)
        error_gui.run()
        return

    try:
        target_time = parse_time(sys.argv[1])
    except Exception as e:
        mes = f"Invalid time string: {e}"
        print(mes)
        error_gui = ErrorGUI(mes)
        error_gui.run()
        return

    message = " ".join(sys.argv[2:])

    gui = TimerGUI(target_time, message)
    gui.run()


if __name__ == "__main__":
    main()
