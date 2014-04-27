import std.getopt,
       std.stdio,
       std.file;

import y4md;

void main(string[] args)
{
    if (args.length != 3)
    {
        writefln("Convert a Y4M file to a YUV file, keeping the chroma-subsampling.");
        writefln("Usage: y4m2yuv <input-file.y4m> <output-file.yuv>");
        return;
    }
    string inputFile = args[1];
    string outputFile = args[2];

    ubyte YUV[];

    try
    {
        auto input = new Y4MReader(inputFile);

        writefln("Input: %s %sx%s %sfps", inputFile, input.width, input.height, cast(double)(input.framerate.num) / (input.framerate.denom));
        int numFrames = 0;
        ubyte[] frameBytes;
        while ( (frameBytes = input.readFrame()) !is null)
        {
            YUV ~= frameBytes;
            numFrames++;
        }
        std.file.write("output.yuv", YUV);

        writefln("Encoded %s frames", numFrames);
    }
    catch(Exception e)
    {
        writefln("%s", e.msg);
        return;
    }
}


