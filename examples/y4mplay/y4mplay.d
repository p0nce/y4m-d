import std.stdio;
import std.typecons;
import std.string;

import y4md;
import gfm.sdl2;

// TODO proper support for aspect ratios
// TODO fullscreen playback
// TODO high bit depth support
// TODO 4:2:2 and 4:4:4 support

void main(string[] args)
{    
    if (args.length != 2)
    {
        writefln("Displays a 4:2:0 8 bits Y4M.");
        writefln("Usage: y4mplay <input-file.y4m>");
        return;
    }
    string inputFile = args[1];

    try
    {
        auto input = new Y4MReader(inputFile);

        if (input.bitdepth != 8)
            throw new Exception("Only 8-bit supported");

        if (!is420Subsampling(input.subsampling))
            throw new Exception("Only 4:2:0 supported");

        writefln("Input: %s %sx%s %sfps", inputFile, input.width, input.height, cast(double)(input.framerate.num) / (input.framerate.denom));

        auto sdl2 = scoped!SDL2(null);
        auto window = scoped!SDL2Window(sdl2, SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, input.width, input.height, 0);
        auto renderer = scoped!SDL2Renderer(window);
        auto texture = scoped!SDL2Texture(renderer, SDL_PIXELFORMAT_IYUV, SDL_TEXTUREACCESS_STREAMING, input.width, input.height);

        int numFrames = 0;
        ubyte[] frameBytes;

        double framerate = cast(double)(input.framerate.num) / (input.framerate.denom);
        double frameMs = 1000.0 / framerate;
        
        double time = 0;
        uint lastTime = SDL_GetTicks();

        while (!sdl2.wasQuitRequested())
        {
            sdl2.processEvents();

            // wait a bit
            uint now = SDL_GetTicks();

            if ((now - lastTime) >= frameMs)
            {
                lastTime += frameMs;

                if ( (frameBytes = input.readFrame()) !is null)
                {
                    int YplaneSize = input.width * input.height;
                    int UVplaneSize = (input.width * input.height) / 4;
                    ubyte* pY = frameBytes.ptr;
                    ubyte* pU = pY + YplaneSize;
                    ubyte* pV = pU + UVplaneSize;
                    int Ypitch = input.width;
                    int Upitch = input.width / 2;
                    int Vpitch = input.width / 2;
                    texture.updateYUVTexture(pY, Ypitch, pU, Upitch, pV, Vpitch);
                    renderer.copy(texture, 0, 0);
                    renderer.present();
                    
                    window.setTitle(format("Frame #%s", numFrames));
                    numFrames++;
                }
            }
        }
    }
    catch(Exception e)
    {
        writefln("%s", e.msg);
        return;
    }
}


