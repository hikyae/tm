# tm

Cross-Platform CLI Timer with GUI Countdown and Beep Alert

## Demo

An example from my environment using a window manager (Sway), a launcher program (Wofi).

![Demo video](https://github.com/user-attachments/assets/956ff4da-1ffa-47dd-af4e-2806220e647e)

## Features

- **Cross-platform sound generation** using `numpy` and `pygame` — no external audio files required.
- **Simple command-line interface** for setting timers with intuitive time formats.
- **Real-time countdown display** via a minimal GUI window using `pygame`.
- **Custom message display** when time is up, shown in a new window.
- **Beeping alert loop** to notify the user when the timer ends.
- Works on **Linux, macOS, and Windows**.

## Dependencies

- Python 3.6+
- [`pygame`](https://pypi.org/project/pygame/)
- [`numpy`](https://pypi.org/project/numpy/)

Install dependencies with:

```bash
pip install pygame numpy
```

## Usage

```bash
python tm <time> <message>
```

### Time Format

You can specify the time in two formats:

1. **Target clock time (24-hour format)**:
   ```
   HH:MM[:SS]
   ```
   Example:
   ```
   python tm 14:30 Lunch time!
   ```

2. **Duration format**:
   ```
   [12h][34m][56s]
   ```
   Examples:
   ```
   python tm 5m Break is over!
   python tm 1h30m Meeting starts
   ```

## What Happens When Time Is Up

- The timer switches to a new window showing your custom message.
- A beeping sound is played repeatedly until you **acknowledge** the alert.
- You can stop the sound and exit the program by:
  - **Pressing** Enter, Escape, or Space key
  - **Clicking** the message text
  - **Closing** the window

## Notes

- The time format must exactly match one of the two described above. Otherwise, an error will be shown and no window will be displayed.
- The fonts used to render Japanese text (`"Cica"`, `"Noto Sans CJK JP"`, `"Meiryo UI"`, `"Yu Gothic UI"`) are specified for personal use. You may need to modify the font setting depending on your environment.

## License

This project is released under the MIT License.
