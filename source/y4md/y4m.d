module y4md.y4m;

import std.stdio,
       std.string,
       std.algorithm,
       std.conv;

struct Rational
{
    int num;
    int denom;
}

class Y4MException : Exception
{
    public
    {
        @safe pure nothrow this(string message, string file =__FILE__, size_t line = __LINE__, Throwable next = null)
        {
            super(message, file, line, next);
        }
    }
}

enum Interlacing
{
    Progressive,
    TopFieldFirst,
    BottomFieldFirst,
    MixedModes
}


enum Subsampling
{
    C420,     /// 4:2:0 with coincident chroma planes
    C422,     /// 4:2:2 with coincident chroma planes
    C444,     /// 4:4:4 with coincident chroma planes
    C420jpeg, /// 4:2:0 with biaxially-displaced chroma planes
    C420paldv /// 4:2:0 with vertically-displaced chroma planes
}

struct Y4MDesc
{
    int width = 0;
    int height = 0;
    Rational framerate = Rational(0,0);
    Rational pixelAR = Rational(0, 0); // default: unknown
    Interlacing interlacing = Interlacing.Progressive;
    Subsampling subsampling = Subsampling.C420;

    size_t frameSize()
    {
        final switch (subsampling)
        {
            case Subsampling.C420:
            case Subsampling.C420jpeg:
            case Subsampling.C420paldv:
                return (width * height * 3) / 2;

            case Subsampling.C422:
                return width * height * 2;

            case Subsampling.C444:
                return width * height * 3;
        }
    }
}


/// Instantiate this to read sequentially frame of a Y4M file.
class Y4MReader
{
    public
    {
        Y4MDesc desc;
        alias desc this;

        this(string inputFile)
        {
            _file = File(inputFile, "rb");
            _index = 0;
            _hasPeek = false;
            fetchHeader();

            _frameBuffer.length = frameSize();
        }

        // null if no more frames
        ubyte[] readFrame()
        {
            if (_index == _file.size())
                return null; // end of input

            // read 5 bytes
            string frame = "FRAME";

            for (int i = 0; i < 5; ++i)
                if (frame[i] != next())
                    throw new Y4MException("Expected \"FRAME\" in y4m.");

            fetchParamList();

            _index += _frameBuffer.length;
            ubyte[] res = _file.rawRead!ubyte(_frameBuffer[]);
            if (res.length != _frameBuffer.length)
                throw new Y4MException(format("Incomplete frame at end of y4m file: expected %s bytes, got %s.", _frameBuffer.length, res.length));

            return res;
        }
    }

    private
    {
        ubyte[] _frameBuffer;
        File _file;
        size_t _index;
        ubyte _peeked;
        bool _hasPeek;
        

        /// Returns: current byte in input and do not advance cursor.
        ubyte peek()
        {
            if (!_hasPeek)
            {
                ubyte[1] buf;
                ubyte[] res = _file.rawRead!ubyte(buf[0..1]);
                _index += 1;

                if (res.length != 1)
                    throw new Y4MException("Wrong y4m, no enough bytes.");

                _peeked = buf[0];

                _hasPeek = true;
            }
            return _peeked;
        }

        /// Returns: current byte in input and advance cursor.
        ubyte next()
        {
            ubyte current = peek();
            _hasPeek = false;
            return current;
        }

        void fetchHeader()
        {
            // read first 9 bytes
            string magic = "YUV4MPEG2";

            for (int i = 0; i < 9; ++i)
                if (magic[i] != next())
                    throw new Y4MException("Wrong y4m header.");

            fetchParamList();
        }

        void fetchParamList()
        {
            Rational parseRatio(string p, Rational defaultValue)
            {
                if (p.length < 3)
                    throw new Y4MException("Wrong y4m header, missing chars in fraction.");

                ptrdiff_t index = countUntil(p, ":");
                if (index == -1)
                    throw new Y4MException("Wrong y4m header, expected ':' in fraction.");

                if (index == 0)
                    throw new Y4MException("Wrong y4m header, missing numerator in fraction.");

                if (index + 1 == p.length)
                    throw new Y4MException("Wrong y4m header, missing denominator in fraction.");

                int num = to!int(p[0..index]);
                int denom = to!int(p[index + 1..$]);

                if (denom == 0)
                    return defaultValue;

                return Rational(num, denom);
            }

            string param;
            while ( (param = fetchParam()) !is null)
            {
                if (param[0] == 'W')
                {
                    width = to!int(param[1..$]);
                }
                else if (param[0] == 'H')
                {
                    height = to!int(param[1..$]);
                }
                else if (param[0] == 'F')
                {
                    framerate = parseRatio(param[1..$], Rational(0));
                }
                else if (param[0] == 'I')
                {
                    bool known = false;
                    for(auto inter = Interlacing.min; inter <= Interlacing.max; ++inter)
                    {
                        if (param == interlacingString(inter))
                        {
                            interlacing = inter;
                            known = true;
                            break;
                        }
                    }
                    if (!known)
                        throw new Y4MException(format("Unsupported y4m interlacing attribute %s", param));
                }
                else if (param[0] == 'A')
                {
                    pixelAR = parseRatio(param[1..$], Rational(1, 1));
                }
                else if (param[0] == 'C')
                {
                    bool known = false;
                    for(auto sub = Subsampling.min; sub <= Subsampling.max; ++sub)
                    {
                        if (param == subsamplingString(sub))
                        {
                            subsampling = sub;
                            known = true;
                            break;
                        }
                    }
                    if (!known)
                        throw new Y4MException(format("Unsupported y4m subsampling attribute %s", param));
                }
                else if (param[0] == 'X')
                {
                    // comment, ignored
                }
                else
                    throw new Y4MException(format("Unsupported y4m attribute %s", param));
            }

            // check mandatory params
            if (width == 0)
                throw new Y4MException(format("Missing width in y4m.", param));
            if (height == 0)
                throw new Y4MException(format("Missing height in y4m.", param));
            if (framerate.num == 0 && framerate.denom == 0)
                throw new Y4MException(format("Missing framerate in y4m.", param));

        }

        // read parameter (space then alphanum+)
        // null if no parameters
        string fetchParam()
        {
            ubyte b = peek();
            if (b == '\n')
            {
                next();
                return null; // end of parameter list
            }
            else if (b == ' ')
            {
                next();
                string result = "";

                while(true)
                {
                    ubyte c = peek();
                    if (c == ' ')
                        break;
                    if (c == 10)
                        break;
                    next();
                    result ~= c;
                }

                return result;
            }
            else
                throw new Y4MException("Wrong y4m, unexpected character.");

        }
    }
}

/// Instantiate this to write sequentially frames into a Y4M file.
class Y4MWriter
{
    public
    {
        Y4MDesc desc;
        alias desc this;

        this(string outputFile, int width, int height, 
             Rational framerate = Rational(0, 0),
             Rational pixelAR = Rational(0, 0), // default: unknown
             Interlacing interlacing = Interlacing.Progressive,
             Subsampling subsampling = Subsampling.C420)
        {
            _file = File(outputFile, "wb");
            this.width = width;
            this.height = height;
            this.framerate = framerate;
            this.pixelAR = pixelAR;
            this.interlacing = interlacing;
            this.subsampling = subsampling;

            string header = format("YUV4MPEG2 W%s H%s F%s:%s A%s:%s %s %s\n", 
                                   width, height, framerate.num, framerate.denom, pixelAR.num, pixelAR.denom,
                                   interlacingString(interlacing), subsamplingString(subsampling));
            

            _file.rawWrite!char(header[]);
        }

        void writeFrame(ubyte[] frameData)
        {
            if (frameData.length != frameSize)
                assert(false); // unrecoverable error, contract not followed

            static immutable string FRAME = "FRAME\n";

            _file.rawWrite!char(FRAME[]);
            _file.rawWrite!ubyte(frameData[]);
        }
    }

    private
    {
        File _file;
    }
}

private
{
    string interlacingString(Interlacing interlacing) pure nothrow
    {
        final switch(interlacing)
        {
            case Interlacing.Progressive:      return "Ip";
            case Interlacing.TopFieldFirst:    return "It";
            case Interlacing.BottomFieldFirst: return "Ib";
            case Interlacing.MixedModes:       return "Im";
        }
    }

    string subsamplingString(Subsampling subsampling) pure nothrow
    {
        final switch(subsampling)
        {
            case Subsampling.C420:      return "C420";
            case Subsampling.C422:      return "C422";
            case Subsampling.C444:      return "C444";
            case Subsampling.C420jpeg:  return "C420jpeg";
            case Subsampling.C420paldv: return "C420paldv";
        }
    }
}
