#ifdef __linux__

//#include <asm/types.h>
#include <linux/posix_types.h>

#undef __SIZEOF_INT128__
#include <linux/types.h>

#include <sys/ioctl.h>
#include <unistd.h>

#include <linux/if.h>
#include <linux/if_tun.h>
#include <linux/in.h>

enum
{
	_TUNSETIFF = TUNSETIFF,
	_TUNSETVNETHDRSZ = TUNSETVNETHDRSZ,
	_TUNSETOFFLOAD = TUNSETOFFLOAD,
	_IFNAMSIZ = IFNAMSIZ,
	_AF_INET = AF_INET,

	_IFF_VNET_HDR = IFF_VNET_HDR,
	_TUN_F_CSUM = TUN_F_CSUM,
	_TUN_F_TSO4 = TUN_F_TSO4,
	_TUN_F_TSO6 = TUN_F_TSO6,
	_TUN_F_TSO_ECN = TUN_F_TSO_ECN,
	_TUN_F_USO4 = TUN_F_USO4,
	_TUN_F_USO6 = TUN_F_USO6
};

#else

#include <io.h>

#endif

#include <fcntl.h>
#include <sys/stat.h>
#include <stdio.h>
