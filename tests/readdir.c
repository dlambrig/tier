#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <dirent.h>     /* Defines DT_* constants */
#include <stdlib.h>
#include <sys/stat.h>
#include <sys/syscall.h>

/* This program works on 64 bit machines only. */

#define handle_error(msg) \
        do { perror(msg); exit(EXIT_FAILURE); } while (0)

struct linux_dirent {
        long           d_ino;
        off_t          d_off;
        unsigned short d_reclen;
        char           d_name[];
};

#define BUF_SIZE 1024

void usage (void)
{
        printf ("Usage: readdir <dirpath> count delay\n");
        printf ("count must be less than %d\n", BUF_SIZE);
        return;
}


int main (int argc, char *argv[])
{
        int fd, nread;
        char buf[BUF_SIZE];
        struct linux_dirent *d;
        int bpos;
        char d_type;
        char *file_path = NULL;
        int count, delay;

        if (argc != 4) {
                usage ();
                exit (1);
        }

        file_path = argv[1];

        count = atoi (argv[2]);
        if (count > BUF_SIZE) {
                usage ();
                exit (1);
        }

        delay = atoi (argv[3]);

        fd = open(file_path, O_RDONLY | O_DIRECTORY);
        if (fd == -1)
                handle_error("open");

        for ( ; ; ) {
                nread = syscall(SYS_getdents, fd, buf, count/2);
                if (nread == -1)
                        handle_error("getdents");
                if (nread == 0)
                        break;
                printf("--------------- nread=%d ---------------\n", nread);
                for (bpos = 0; bpos < nread;) {
                        d = (struct linux_dirent *) (buf + bpos);
                        printf("%s (%d)\n", d->d_name, d->d_reclen);
                        bpos += d->d_reclen;
                }
                sleep(delay);
        }

}
