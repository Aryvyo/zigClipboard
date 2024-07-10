# Zig Clipboard Tracker

My first project in zig, acts as a drop-in tracker for the X11 Selection server (clipboard).
This does not take ownership of the selection except when you copy from it, I don't aim to disrupt the usual flow
of the server
![image](https://github.com/Aryvyo/zigClipboard/assets/32790578/139621ed-3297-4986-87e6-bd17adfcff12)

## Usage

its as easy as downloading and
```./zigClipManager```

## Installation

A built file should be available in the releases, however if you instead wish to build it yourself:

Using zig 0.13.0 

Download `zgui`, `zglfw` and `system-sdk` from [zig-gamdev/libs](https://github.com/zig-gamedev/zig-gamedev/tree/main/libs)
and place them in a folder named `libs` in the root directory of this project

You will also need libx11-dev, please make sure you change the include path in `build.zig`.

Once you have all that, you should be able to run 
```zig build run```


***PLEASE REMEMBER TO DOWNLOAD ALL REQUIRED LIBRARIES BEFORE DMING ME***

Feel free to contact me on [X](https://x.com/aryvyo) if you are encountering issues

## Contributions

I will try to ship all required features myself, but I will only really work on this as long as I require it.
If you wish to contribute, simply fork the repo, make any changes and make a pull request :)

Look below for a place to start ^-^

## TO-DO

- [ ] Add image support
- [ ] Add support for hiding window
- [ ] Add icon (no one do this)
