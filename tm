#!/bin/env python3
import datetime
import re
import sys
import threading
import time

import numpy as np
import pygame

BLACK = (0, 0, 0)
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


def main():
    if len(sys.argv) < 3:
        print("Usage: tm HH:MM[:SS] message")
        return

    try:
        target_time = parse_time(sys.argv[1])
    except Exception as e:
        print("Invalid time string:", e)
        return

    message = " ".join(sys.argv[2:])

    pygame.mixer.init(frequency=SAMPLE_RATE, size=-16, channels=1)
    pygame.init()

    pygame.display.set_caption("timer")
    screen = pygame.display.set_mode((100, 50))
    time_font = pygame.font.SysFont(None, 28)
    msg_font = pygame.font.SysFont(("Cica", "Noto Sans CJK JP"), 30)

    running = True
    counting_down = True
    msg_rect = None
    stop_event = threading.Event()
    beep_thread = None

    while running:
        remaining = target_time - time.time()
        screen.fill(BLACK)

        if counting_down:
            rem_int = int(remaining + 1)
            hrs = rem_int // 3600
            mins = (rem_int % 3600) // 60
            secs = rem_int % 60
            time_str = f"{hrs:02}:{mins:02}:{secs:02}"
            time_img = time_font.render(time_str, True, GREEN)
            screen.blit(time_img, get_center_rect(screen, time_img))
            pygame.display.update()

            if remaining <= 0:
                counting_down = False

                beep_thread = threading.Thread(target=beep_loop, args=(stop_event,))
                beep_thread.start()

                msg_img = msg_font.render(message, True, GREEN)
                pygame.display.set_caption("time is up")
                screen = pygame.display.set_mode((msg_img.get_width() + 20, 50))
                msg_rect = get_center_rect(screen, msg_img)
                screen.blit(msg_img, msg_rect)
                pygame.display.update()

        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif remaining <= -0.5 and (
                event.type == pygame.MOUSEBUTTONDOWN
                and msg_rect.collidepoint(event.pos)
                or event.type == pygame.KEYDOWN
                and event.key
                in (
                    pygame.K_RETURN,
                    pygame.K_ESCAPE,
                    pygame.K_SPACE,
                )
            ):
                # keep showing message at least for 0.5 seconds
                # even if space key is pressed accidentally
                stop_event.set()
                if beep_thread:
                    beep_thread.join()
                running = False

        time.sleep(0.1)

    pygame.quit()


if __name__ == "__main__":
    main()
