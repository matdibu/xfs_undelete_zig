#include "xfs_exceptions.hpp"

using uf::xfs::ValidationException;

ValidationException::ValidationException(const char* const Message)
    : m_message(Message)
{}

ValidationException::ValidationException(std::string Message) noexcept
    : m_message(std::move(Message))
{}

const char* ValidationException::what() const noexcept
{
    return m_message.c_str();
}
