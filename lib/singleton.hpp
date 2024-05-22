#ifndef _SINGLETON_HPP_
#define _SINGLETON_HPP_

#include <mutex> // std::unique_lock std::mutex

namespace utils {
    template <typename T>
    struct SingletonHeap;

    template <typename T>
    struct SingletonLazy;
} // namespace utils

template <typename T>
struct utils::SingletonHeap
{
public:
    SingletonHeap(const SingletonHeap&) = delete;
    SingletonHeap& operator=(const SingletonHeap&) = delete;

    SingletonHeap(SingletonHeap&&) = delete;
    SingletonHeap& operator=(SingletonHeap&&) = delete;

    static T* GetInstance()
    {
        std::unique_lock<std::mutex> lock(m_mutex);
        if (m_ref == 0)
        {
            m_ptr = new T();
            try
            {
                m_ptr->Init();
            }
            catch (...)
            {
                delete m_ptr;
                m_ptr = nullptr;
                throw;
            }
        }
        m_ref++;
        return m_ptr;
    }

    static void ReleaseInstance()
    {
        std::unique_lock<std::mutex> lock(m_mutex);
        if (--m_ref == 0)
        {
            delete m_ptr;
            m_ptr = nullptr;
        }
    }

    virtual void Init() {}

protected:
    SingletonHeap() = default;
    virtual ~SingletonHeap() = default;

private:
    static std::mutex m_mutex;
    static T*         m_ptr;
    static int        m_ref;
};

template <typename T>
struct utils::SingletonLazy
{
public:
    SingletonLazy(const SingletonLazy&) = delete;
    SingletonLazy& operator=(const SingletonLazy&) = delete;
    SingletonLazy(SingletonLazy&&) = delete;
    SingletonLazy& operator=(SingletonLazy&&) = delete;

    static T& GetInstance()
    {
        static T t;
        return t;
    }

    static T* GetInstancePtr()
    {
        return &(GetInstance());
    }

protected:
    SingletonLazy()          = default;
    virtual ~SingletonLazy() = default;
};

// initialization
namespace utils {
    template <class T>
    std::mutex SingletonHeap<T>::m_mutex;

    template <class T>
    int SingletonHeap<T>::m_ref = 0;

    template <class T>
    T* SingletonHeap<T>::m_ptr = nullptr;
} // namespace utils

#endif // !_SINGLETON_HPP_
