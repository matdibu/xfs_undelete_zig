#include "xfs_inode.hpp"

#include "xfs_exceptions.hpp" // ValidationException

using uf::xfs::Inode;
using uf::xfs::ValidationException;

Inode::Inode(const xfs_inode& InodeHeader)
    : m_inodeHeader(InodeHeader)
{
    Validate();
}

void Inode::SetExtents(std::vector<Extent> Extents) noexcept
{
    m_extents = std::move(Extents);
}

const std::vector<uf::xfs::Extent>& Inode::GetExtents() const noexcept
{
    return m_extents;
}

void Inode::Validate() const
{
    if (XFS_DINODE_MAGIC != be16toh(m_inodeHeader.di_magic))
    {
        throw ValidationException("bad magic");
    }
    if (0 != m_inodeHeader.di_mode)
    {
        throw ValidationException("non-zero mode");
    }
    if (3 != m_inodeHeader.di_version)
    {
        throw ValidationException("version is not 3");
    }
    if (XFS_DINODE_FMT_EXTENTS != m_inodeHeader.di_format)
    {
        throw ValidationException("format is not EXTENTS");
    }
    if (0 != m_inodeHeader.di_nlink)
    {
        throw ValidationException("non-zero nlink");
    }
}

xfs_ino_t Inode::GetInodeNumber() const noexcept
{
    return be64toh(m_inodeHeader.di_ino);
}

xfs_timestamp_t Inode::GetATime() const noexcept
{
    xfs_timestamp_t result{};
    result.t_sec  = be32toh(m_inodeHeader.di_atime.t_sec);
    result.t_nsec = be32toh(m_inodeHeader.di_atime.t_nsec);
    return result;
}

xfs_timestamp_t Inode::GetMTime() const noexcept
{
    xfs_timestamp_t result{};
    result.t_sec  = be32toh(m_inodeHeader.di_mtime.t_sec);
    result.t_nsec = be32toh(m_inodeHeader.di_mtime.t_nsec);
    return result;
}

xfs_timestamp_t Inode::GetCTime() const noexcept
{
    xfs_timestamp_t result{};
    result.t_sec  = be32toh(m_inodeHeader.di_ctime.t_sec);
    result.t_nsec = be32toh(m_inodeHeader.di_ctime.t_nsec);
    return result;
}

xfs_timestamp_t Inode::GetCrTime() const noexcept
{
    xfs_timestamp_t result{};
    result.t_sec  = be32toh(m_inodeHeader.di_crtime.t_sec);
    result.t_nsec = be32toh(m_inodeHeader.di_crtime.t_nsec);
    return result;
}
