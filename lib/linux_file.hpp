#ifndef _LINUX_FILE_HPP_
#define _LINUX_FILE_HPP_

#include "pandora_exceptions.hpp" // utils::ErrnoException

#include <string>
#include <vector>

namespace utils {
    class LinuxFile;
    class LinuxFileException;
} // namespace utils

class utils::LinuxFile
{
public:
    LinuxFile();
    // opens existing file
    explicit LinuxFile(const std::string& FilePath);
    explicit LinuxFile(const std::string& FilePath, int Flags);
    explicit LinuxFile(const std::string& FilePath, int Flags, mode_t Mode);
    explicit LinuxFile(const std::string& FilePath, bool Create, bool ReadOnly);

    LinuxFile(const LinuxFile&);
    LinuxFile& operator=(const LinuxFile&);

    LinuxFile(LinuxFile&&) noexcept;
    LinuxFile& operator=(LinuxFile&&) noexcept;

    virtual ~LinuxFile() noexcept;

    size_t ReadFromOffset(void* Buffer, off_t Offset, uint64_t Size) const;

    size_t WriteAtOffset(const void* Buffer, off_t Offset, uint64_t Size) const;

    void Flush() const;

    const std::string& GetFilePath() const noexcept;

    ino_t GetInode() const;

    void Delete();
    void PreAllocate(off_t Offset, off_t Size) const;
    int  Ioctl(uint64_t Request) const;
    int  Ioctl(uint64_t Request, int Arg) const;
    int  Ioctl(uint64_t Request, void* Arg) const;
    void CopyFromFile(const LinuxFile& Other, off_t Offset, uint64_t Size) const;

    bool IsOpen() const noexcept;

    int      GetDescriptor() const;
    uint64_t GetBlocksize() const;
    off_t    GetFileSize() const;
    time_t   GetMTime() const;
    time_t   GetATime() const;
    time_t   GetCTime() const;

    void Close();

private:
    int         m_Descriptor;
    std::string m_AbsolutePath;
};

class utils::LinuxFileException : public ErrnoException
{
public:
    explicit LinuxFileException(const char* Message, int Errno);
    explicit LinuxFileException(const char* Message);
};

#endif // !_LINUX_FILE_HPP_
