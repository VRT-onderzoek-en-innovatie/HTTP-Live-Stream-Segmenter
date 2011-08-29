AC_INIT([segmenter],
	[0.0.01],
	[Niels Laukens niels.laukens@vrtmedialab.be],
	[segmenter])
AC_CONFIG_AUX_DIR(config)
AC_CONFIG_HEADERS(config.h)     dnl output results to config.h
AM_INIT_AUTOMAKE([dist-bzip2 subdir-objects -Wall])

# Options
#########

# Checks for programs
#####################
AC_PROG_CC
AC_PROG_CXXCPP
AC_PROG_CXX
AC_LANG_CPLUSPLUS
AC_C_INLINE

# Library checks
################
AC_CHECK_LIB(crypto, AES_set_encrypt_key, [], [AC_MSG_ERROR([Couldn't find libcrypto])], [])


# Header checks
###############
AC_CHECK_HEADER([openssl/aes.h], [], [AC_MSG_ERROR([Couldn't find openssl headers])], [])


# Typedefs & structs
####################


# Functions
###########


# Output
########
AC_CONFIG_FILES([
	Makefile
	src/Makefile
	test/Makefile
	])

AC_OUTPUT
