dnl
dnl $Id$
dnl
dnl This file contains helper autoconf functions for php_ext_embed
dnl

PHP_ARG_WITH(libelf, with libelf path,
[  --with-libelf   search libelf at this path], /usr)

ext_embed_files_header=ext_embed_libs.h

AC_DEFUN([PHP_EXT_EMBED_CHECK_VALID],[
  if test "$PHP_EXT_EMBED_DIR" = ""; then
  	PHP_EXT_EMBED_DIR=php-ext-embed
  fi
])


dnl
dnl PHP_EXT_EMBED_NEW_EXTENSION(extname, sources [, shared [, sapi_class [, extra-cflags [, cxx [, zend_ext]]]]])
dnl
dnl Includes an extension in the build.
dnl 
dnl It is a wrapper for PHP_NEW_EXTENSION to inculude php_ext_embed.c
dnl
dnl "extname" is the name of the ext/ subdir where the extension resides.
dnl "sources" is a list of files relative to the subdir which are used
dnl to build the extension.
dnl "shared" can be set to "shared" or "yes" to build the extension as
dnl a dynamically loadable library. Optional parameter "sapi_class" can
dnl be set to "cli" to mark extension build only with CLI or CGI sapi's.
dnl "extra-cflags" are passed to the compiler, with 
dnl @ext_srcdir@ and @ext_builddir@ being substituted.
dnl "cxx" can be used to indicate that a C++ shared module is desired.
dnl "zend_ext" indicates a zend extension.
AC_DEFUN([PHP_EXT_EMBED_NEW_EXTENSION],[
  PHP_EXT_EMBED_CHECK_VALID()

  if test "$3" == "yes" || test "$3" == "shared"; then
  	CFLAGS="$CFLAGS -DPHP_EXT_EMBED_SHARED=1"
  	CXXFLAGS="$CXXFLAGS -DPHP_EXT_EMBED_SHARED=1"
  fi

  PHP_NEW_EXTENSION($1, [$2 $PHP_EXT_EMBED_DIR/php_ext_embed.c], $3, $4, $5, $6, $7)

  case $host_alias in
    *linux*[)]
      dnl FIXME tricky way to add custom command after build for Linux
      echo "	objcopy $php_ext_embed_libs .libs/$1.so" >> Makefile.objects
      ;;
  esac
])

dnl
dnl PHP_EXT_EMBED_INIT(extname)
dnl
dnl check dependencies
dnl
dnl "extname" is the name of the ext/ subdir where the extension resides.
AC_DEFUN([PHP_EXT_EMBED_INIT],[
  PHP_EXT_EMBED_CHECK_VALID()

  AC_MSG_CHECKING([whether php_ext_embed_dir is correct])
  if test -f "$PHP_EXT_EMBED_DIR/php_ext_embed.h"; then
    AC_MSG_RESULT([yes])
  else
    AC_MSG_ERROR([php_ext_embed.h is not exist])
  fi

  PHP_ADD_INCLUDE($PHP_EXT_EMBED_DIR)

  which dpkg-architecture 2>&1 > /dev/null

  if [[ $? == 0 ]]; then
	DEB_HOST_MULTIARCH=`dpkg-architecture -qDEB_HOST_MULTIARCH`
  fi
 
  AC_MSG_CHECKING([whether libelf is found])

  EXT_EMBED_SEARCH_PATH="$PHP_LIBELF /usr/local /usr $LIBRARY_PATH $LD_LIBRARY_PATH"

  for i in $EXT_EMBED_SEARCH_PATH; do
    EXT_EMBED_SEARCH_INCLUDE="$EXT_EMBED_SEARCH_INCLUDE $i/include $i/include/libelf"
  done

  AC_MSG_CHECKING(search libelf in $EXT_EMBED_SEARCH_PATH)

  EXT_EMBED_SEARCH_FOR="libelf.h"
  SEARCH_LIB="libelf"

  for i in $EXT_EMBED_SEARCH_INCLUDE; do
    if test "$EXT_EMBED_LIBELF_INCLUDE_DIR" != "" && test "$EXT_EMBED_LIBELF_LIB_DIR" != ""; then
      break
    fi

    if test -r $i/$EXT_EMBED_SEARCH_FOR; then
      EXT_EMBED_LIBELF_INCLUDE_DIR=$i
      AC_MSG_RESULT(libelf header found header in $i)
    fi
  done

  for i in $EXT_EMBED_SEARCH_PATH; do
    if test "$EXT_EMBED_LIBELF_LIB_DIR" != ""; then
      continue
    fi

	BASELIB=$i/$PHP_LIBDIR

    if test -r $BASELIB/$DEB_HOST_MULTIARCH/$SEARCH_LIB.a || test -r $BASELIB/$DEB_HOST_MULTIARCH/$SEARCH_LIB.$SHLIB_SUFFIX_NAME; then
      EXT_EMBED_LIBELF_LIB_DIR=$BASELIB/$DEB_HOST_MULTIARCH
      AC_MSG_RESULT(libelf lib found in $EXT_EMBED_LIBELF_LIB_DIR)
	  continue
    fi

    if test -r $BASELIB/$SEARCH_LIB.a || test -r $BASELIB/$SEARCH_LIB.$SHLIB_SUFFIX_NAME; then
      EXT_EMBED_LIBELF_LIB_DIR=$BASELIB
      AC_MSG_RESULT(libelf lib found in $EXT_EMBED_LIBELF_LIB_DIR)
    fi
  done

  if test "$EXT_EMBED_LIBELF_INCLUDE_DIR" == "" || test "$EXT_EMBED_LIBELF_LIB_DIR" == ""; then
    AC_MSG_ERROR([libelf not found])
  fi

  PHP_ADD_INCLUDE($EXT_EMBED_LIBELF_INCLUDE_DIR)
  PHP_ADD_LIBRARY_WITH_PATH(elf, $EXT_EMBED_LIBELF_LIB_DIR, SAMPLE_SHARED_LIBADD)
])

dnl
dnl PHP_EXT_EMBED_ADD_LIB(extname, sources)
dnl
dnl Includes php lib to extension
dnl
dnl "extname" is the name of the ext/ subdir where the extension resides.
dnl "sources" is a list of files relative to the subdir which need to be
dnl           embeded to extension
AC_DEFUN([PHP_EXT_EMBED_ADD_LIB],[
  php_ext_upper_name=translit($1,a-z-,A-Z_)
  AC_MSG_RESULT(Generate embed files header)
  echo "" > $ext_embed_files_header

  echo "/* Generated by php-ext-embed don't edit it */"  >> $ext_embed_files_header
  echo ""                         >> $ext_embed_files_header
  echo "#ifndef _PHP_EXT_EMBED_${php_ext_upper_name}_"  >> $ext_embed_files_header
  echo "#define _PHP_EXT_EMBED_${php_ext_upper_name}_"  >> $ext_embed_files_header
  echo ""                      >> $ext_embed_files_header
  echo "php_ext_lib_entry ext_$1_embed_files[[]] = {"    >> $ext_embed_files_header

  php_ext_embed_libs=
  case $host_alias in
    *darwin*[)]
      MD5_CMD=md5
      ;;
  *[)]
      MD5_CMD=md5sum
      ;;
  esac

  for ac_src in $2; do
    if test -f "$ac_src"; then
      dummy_filename="extension://$1/$ac_src"
      dnl TODO Linux
      section_name=ext.`echo $dummy_filename | $MD5_CMD`
      section_name=${section_name:0:16}
      echo "  {"            >> $ext_embed_files_header
      echo "    \"$ac_src\"",      >> $ext_embed_files_header
      echo "    \"$dummy_filename\"",  >> $ext_embed_files_header
      echo "    \"$section_name\"",    >> $ext_embed_files_header
      echo "  },"            >> $ext_embed_files_header

      PHP_GLOBAL_OBJS="$PHP_GLOBAL_OBJS $ac_src"
      shared_objects_$1="$shared_objects_$1 $ac_src"

      case $host_alias in
        *darwin*[)]
        dnl Append to LDFLAGS for now There is no way to hook it link stage with needed flags :(
        LDFLAGS="$LDFLAGS -Wl,-sectcreate,__text,${section_name},${ac_src}"
        ;;
        *[)]
        php_ext_embed_libs="$php_ext_embed_libs --add-section "${section_name}=${ac_src}""
        ;;
      esac
    else
      AC_MSG_WARN([lib file $ac_src not found, ignored])
    fi
  done
  echo "  {NULL, NULL, NULL}"                    >> $ext_embed_files_header
  echo "};"                      >> $ext_embed_files_header
  echo ""                      >> $ext_embed_files_header
  echo "#endif"                    >> $ext_embed_files_header
])
