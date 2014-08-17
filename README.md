## What's this?

y4m-d is a tiny library to load/save Y4M video files.
Y4M files are the simplest uncompressed video files that also contain meta-data 
(width, height, chroma subsampling, etc...) which makes a better solution than .yuv files.

High bit-depth are supported with any depth from 8 to 16. 
However y4m-d does not handle endianness or shifted bits in samples. Frames are read/written as is.

libavformat uses native endian for both reading and writing and align significant bits to the left.
This means the Y4M format depends on the producer machine. So until probing is implemented it's up to take care of this.

## Licenses

See UNLICENSE.txt


## Usage


```d

import y4md;

void main(string[] args)
{
    auto input = new Y4MReader("input-file.y4m");

    writefln("Input: %s %sx%s %sfps", inputFile, input.width, input.height,
             cast(double)(input.framerate.num) / (input.framerate.denom));

    ubyte[] frameBytes;
    while ( (frameBytes = input.readFrame()) !is null)
    {
        // Do something with frame data in frameBytes[]
    }


    // Output a 1920x1080p25 stream
    auto output = new Y4MWriter("output-file.y4m", 1920, 1080, Rational(25, 1)); 
    frameBytes = new ubyte[output.frameSize()];
    for (int i = 0; i < 100; ++i)
    {
        // write something in frameData...

        output.writeFrame(frameBytes[]);
    }
}

```
