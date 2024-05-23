#ifndef _PANDORA_EXCEPTIONS_HPP_
#define _PANDORA_EXCEPTIONS_HPP_

#include <exception>

#include <string>

class pandora_exception : public std::exception
{
};
class ErrnoException : public pandora_exception
{
public:
    ErrnoException(const std::string& /*message*/, int /*errno*/) {}
    ErrnoException(const char* /*message*/, int /*errno*/) {}
};

#endif // !_PANDORA_EXCEPTIONS_HPP_
