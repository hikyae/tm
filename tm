#!/bin/env python3
import datetime
import re
import sys
import threading
import time

import numpy as np
import pygame

GREEN = (0, 255, 0)
SAMPLE_RATE = 44100
FREQ = 2000
VOLUME = 0.8


def generate_beep_sound(
    freq=FREQ, duration=0.3, sample_rate=SAMPLE_RATE, volume=VOLUME
):
    t = np.linspace(0, duration, int(sample_rate * duration), endpoint=False)
    waveform = np.sin(2 * np.pi * freq * t) * volume
    mono_waveform = np.int16(waveform * 32767)
    return pygame.sndarray.make_sound(mono_waveform)


def beep_loop(stop_event):
    sound = generate_beep_sound()
    while not stop_event.is_set():
        sound.play()
        time.sleep(0.5)


def parse_duration_or_target(timestr) -> int | float:
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
        return (target - now).total_seconds()
    else:
        # 12h34m56s format
        match = re.fullmatch(r"(?:(\d+)h)?(?:(\d+)m)?(?:(\d+)s)?", timestr)
        if not match:
            raise ValueError("Invalid duration format. Use [12h][34m][56s]")
        m_h, m_m, m_s = match.groups()
        h = int(m_h) if m_h else 0
        m = int(m_m) if m_m else 0
        s = int(m_s) if m_s else 0
        return h * 3600 + m * 60 + s


def get_center_rect(screen, img):
    rect = img.get_rect()
    rect.center = (screen.get_width() // 2, screen.get_height() // 2)
    return rect


def main():
    if len(sys.argv) < 3:
        print("Usage: tm HH:MM[:SS] message")
        return

    try:
        duration = parse_duration_or_target(sys.argv[1])
    except Exception as e:
        print("Invalid time string:", e)
        return

    message = " ".join(sys.argv[2:])

    pygame.mixer.init(frequency=SAMPLE_RATE, size=-16, channels=1)
    pygame.init()

    screen = pygame.display.set_mode((100, 50))
    pygame.display.set_caption("timer")
    time_font = pygame.font.SysFont(None, 28)
    msg_font = pygame.font.SysFont(("Cica", "Noto Sans CJK JP"), 30)

    running = True
    counting_down = True
    msg_rect = None
    stop_event = threading.Event()
    beep_thread = None

    start_time = time.time()

    while running:
        now = time.time()
        remaining = int(duration - (now - start_time) + 1)

        screen.fill((30, 30, 30))

        if counting_down:
            hrs = remaining // 3600
            mins = (remaining % 3600) // 60
            secs = remaining % 60
            time_str = f"{hrs:02}:{mins:02}:{secs:02}"
            time_img = time_font.render(time_str, True, GREEN)
            screen.blit(time_img, get_center_rect(screen, time_img))
            pygame.display.update()

        if remaining <= 0 and counting_down:
            counting_down = False

            beep_thread = threading.Thread(target=beep_loop, args=(stop_event,))
            beep_thread.start()

            msg_img = msg_font.render(message, True, GREEN)
            screen = pygame.display.set_mode((msg_img.get_width() + 20, 50))
            pygame.display.set_caption("time is up")
            msg_rect = get_center_rect(screen, msg_img)
            screen.blit(msg_img, msg_rect)
            pygame.display.update()
            # keep showing message at least for 1 second
            # even if space key is pressed accidentally
            time.sleep(1)

        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif not counting_down and (
                event.type == pygame.MOUSEBUTTONDOWN
                and msg_rect.collidepoint(event.pos)
                or event.type == pygame.KEYDOWN
                and event.key == pygame.K_SPACE
            ):
                stop_event.set()
                if beep_thread:
                    beep_thread.join()
                running = False

        time.sleep(0.1)

    pygame.quit()


if __name__ == "__main__":
    main()
