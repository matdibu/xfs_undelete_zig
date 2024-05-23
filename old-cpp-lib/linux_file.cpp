#include "linux_file.hpp"

#include <spdlog/spdlog.h>

#include <aio.h>
#include <fcntl.h>
#include <linux/fs.h>  // FIGETBSZ
#include <sys/ioctl.h> // ioctl
#include <sys/stat.h>
#include <unistd.h>

#include <array>
#include <string>

using utils::LinuxFile;
using utils::LinuxFileException;

LinuxFile::LinuxFile()
    : m_Descriptor(-1)
    , m_AbsolutePath()
{}

LinuxFile::LinuxFile(const std::string& Path)
    : LinuxFile(Path, O_RDWR | O_CLOEXEC)
{}

LinuxFile::LinuxFile(const std::string& Path, int Flags)
    : LinuxFile(Path, Flags, 0)
{}

LinuxFile::LinuxFile(const std::string& Path, int Flags, mode_t Mode)
{
    // open the file
    if (-1 == (m_Descriptor = open(Path.c_str(), Flags, Mode)))
    {
        int err = errno;
        spdlog::error("open \"{}\" failed: {}", Path.c_str(), strerror(err));
        throw ErrnoException("open", err);
    }

    // read the symlink to get the absolute path
    std::string fdlink        = "/proc/self/fd/" + std::to_string(m_Descriptor);
    char        fullpath[256] = {};

    if (-1 == readlink(fdlink.c_str(), fullpath, sizeof(fullpath)))
    {
        int err = errno;
        spdlog::error("readlink \"{}\" failed: {}", fdlink.c_str(), strerror(err));
        throw ErrnoException("readlink", err);
    }

    m_AbsolutePath = fullpath;
}

LinuxFile::LinuxFile(const std::string& FilePath, bool Create, bool ReadOnly)
    : LinuxFile(FilePath, O_CLOEXEC | (Create ? O_CREAT : 0) | (ReadOnly ? O_RDONLY : O_RDWR), S_IREAD | S_IWUSR)
{}

LinuxFile::LinuxFile(const LinuxFile& Other)
    : LinuxFile()
{
    *this = Other;
}

LinuxFile& LinuxFile::operator=(const LinuxFile& Other)
{
    if (this != &Other) // bypass self-assignment
    {
        if (!Other.IsOpen())
        {
            spdlog::error("File \"{}\"({}) is not open", Other.GetFilePath().c_str(), Other.GetDescriptor());
            throw LinuxFileException("File is not open");
        }

        Close();

        m_Descriptor = fcntl(Other.m_Descriptor, F_DUPFD_CLOEXEC, 0);
        if (m_Descriptor < 0)
        {
            int err = errno;
            spdlog::error(
                "Failed to duplicate file \"{}\"({}). Error: {}",
                Other.GetFilePath().c_str(),
                Other.GetDescriptor(),
                strerror(err));
            throw ErrnoException("Failed to duplicate file", err);
        }

        m_AbsolutePath = Other.m_AbsolutePath;
    }

    return *this;
}

LinuxFile::LinuxFile(LinuxFile&& Other) noexcept
    : LinuxFile()
{
    std::swap(m_Descriptor, Other.m_Descriptor);
    std::swap(m_AbsolutePath, Other.m_AbsolutePath);
}

LinuxFile& LinuxFile::operator=(LinuxFile&& Other) noexcept
{
    if (this != &Other) // bypass self-assignment
    {
        std::swap(m_Descriptor, Other.m_Descriptor);
        std::swap(m_AbsolutePath, Other.m_AbsolutePath);
    }
    return *this;
}

LinuxFile::~LinuxFile() noexcept
{
    try
    {
        Close();
    }
    catch (const std::exception& exc)
    {
        spdlog::error("~LinuxFile failed: {}", exc.what());
    }
}

size_t LinuxFile::ReadFromOffset(void* Buffer, off_t Offset, uint64_t Size) const
{
    ssize_t bytesRead = 0;
    if (0 > (bytesRead = pread64(m_Descriptor, Buffer, Size, Offset)))
    {
        int err = errno;
        spdlog::error("pread64 \"{}\"({}) failed: {}", m_AbsolutePath.c_str(), m_Descriptor, strerror(err));
        throw LinuxFileException("Failed to read from file", err);
    }
    return static_cast<size_t>(bytesRead);
}

size_t LinuxFile::WriteAtOffset(const void* Buffer, off_t Offset, uint64_t Size) const
{
    ssize_t bytesWritten = 0;
    if (0 > (bytesWritten = pwrite64(m_Descriptor, Buffer, Size, Offset)))
    {
        // int err = errno;
        // spdlog::error("pwrite64 \"{}\"({}) failed: {}", m_AbsolutePath.c_str(), m_Descriptor, strerror(err));
        throw LinuxFileException("Failed to write to file");
    }
    return static_cast<size_t>(bytesWritten);
}

void LinuxFile::Flush() const
{
    if (0 != fsync(m_Descriptor))
    {
        int err = errno;
        spdlog::error("fsync \"{}\"({}): {}", m_AbsolutePath.c_str(), m_Descriptor, strerror(err));
        throw ErrnoException("fsync", err);
    }
}

const std::string& LinuxFile::GetFilePath() const noexcept
{
    return m_AbsolutePath;
}

ino_t LinuxFile::GetInode() const
{
    struct stat file_stat = {};
    if (fstat(m_Descriptor, &file_stat) < 0)
    {
        int err = errno;
        spdlog::error("fstat \"{}\"({}) failed: {}", m_AbsolutePath.c_str(), m_Descriptor, strerror(err));
        throw ErrnoException("fstat", err);
    }

    return file_stat.st_ino;
}

void LinuxFile::Delete()
{
    std::string path = m_AbsolutePath; // save the path, Close() clears it

    Close();

    if (0 != remove(path.c_str()))
    {
        int err = errno;
        spdlog::error("remove \"{}\" failed: {}", path.c_str(), strerror(err));
        throw ErrnoException("remove", err);
    }
}

void LinuxFile::PreAllocate(off_t Offset, off_t Size) const
{
    int status = 0;
    if (0 != (status = posix_fallocate(m_Descriptor, Offset, Size)))
    {
        spdlog::error("posix_fallocate: {}", strerror(status));
        throw ErrnoException("posix_fallocate", status);
    }
}

int LinuxFile::GetDescriptor() const
{
    return m_Descriptor;
}

int LinuxFile::Ioctl(uint64_t Request) const
{
    int result = 0;
    if (-1 == (result = ioctl(m_Descriptor, Request)))
    {
        int err = errno;
        spdlog::error("ioctl \"{}\"({}) {}u failed: {}", m_AbsolutePath.c_str(), m_Descriptor, Request, strerror(err));
        throw ErrnoException("ioctl", err);
    }
    return result;
}

int LinuxFile::Ioctl(uint64_t Request, int Arg) const
{
    int result = 0;
    if (-1 == (result = ioctl(m_Descriptor, Request, Arg)))
    {
        int err = errno;
        spdlog::error(
            "ioctl \"{}\"({}) {}u {} failed: {}", m_AbsolutePath.c_str(), m_Descriptor, Request, Arg, strerror(err));
        throw ErrnoException("ioctl", err);
    }
    return result;
}

int LinuxFile::Ioctl(uint64_t Request, void* Arg) const
{
    int result = 0;
    if (0 != (result = ioctl(m_Descriptor, Request, Arg)))
    {
        int err = errno;
        spdlog::error(
            "ioctl \"{}\"({}) {}u {} failed: {}", m_AbsolutePath.c_str(), m_Descriptor, Request, Arg, strerror(err));
        throw ErrnoException("ioctl", err);
    }
    return result;
}

void LinuxFile::CopyFromFile(const LinuxFile& Other, off_t Offset, uint64_t Size) const
{
    std::array<uint8_t, 4096> buffer{};

    while (Size > 0)
    {
        const uint64_t bytesToRead = std::min(static_cast<uint64_t>(buffer.size()), Size);
        Other.ReadFromOffset(buffer.data(), Offset, bytesToRead);
        WriteAtOffset(buffer.data(), Offset, bytesToRead);
        Offset += bytesToRead;
        Size -= bytesToRead;
    }
}

off_t LinuxFile::GetFileSize() const
{
    struct stat stat = {};

    if (-1 == fstat(m_Descriptor, &stat))
    {
        int err = errno;
        spdlog::error("fstat \"{}\"({}) failed: {}", m_AbsolutePath.c_str(), m_Descriptor, strerror(err));
        throw ErrnoException("fstat GetFileSize", err);
    }

    return stat.st_size;
}

time_t LinuxFile::GetMTime() const
{
    struct stat stat = {};

    if (-1 == fstat(m_Descriptor, &stat))
    {
        int err = errno;
        spdlog::error("fstat \"{}\"({}) failed: {}", m_AbsolutePath.c_str(), m_Descriptor, strerror(err));
        throw ErrnoException("fstat GetMTime", err);
    }

    return stat.st_mtim.tv_sec;
}
time_t LinuxFile::GetATime() const
{
    struct stat stat = {};

    if (-1 == fstat(m_Descriptor, &stat))
    {
        int err = errno;
        spdlog::error("fstat \"{}\"({}) failed: {}", m_AbsolutePath.c_str(), m_Descriptor, strerror(err));
        throw ErrnoException("fstat GetATime", err);
    }

    return stat.st_atim.tv_sec;
}
time_t LinuxFile::GetCTime() const
{
    struct stat stat = {};

    if (-1 == fstat(m_Descriptor, &stat))
    {
        int err = errno;
        spdlog::error("fstat \"{}\"({}) failed: {}", m_AbsolutePath.c_str(), m_Descriptor, strerror(err));
        throw ErrnoException("fstat GetCTime", err);
    }

    return stat.st_ctim.tv_sec;
}

bool LinuxFile::IsOpen() const noexcept
{
    return m_Descriptor != -1;
}

void LinuxFile::Close()
{
    if (IsOpen())
    {
        if (-1 == close(m_Descriptor))
        {
            throw ErrnoException("close", errno);
        }
    }

    m_Descriptor = -1;
    m_AbsolutePath.clear();
}

LinuxFileException::LinuxFileException(const char* const Message, const int Err)
    : ErrnoException(Message, Err)
{}

LinuxFileException::LinuxFileException(const char* const Message)
    : ErrnoException(Message, -1)
{}
