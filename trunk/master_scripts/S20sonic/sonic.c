
#define _GNU_SOURCE
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <pthread.h>
#include <assert.h>
#include <time.h>
#include <fcntl.h>

#include <netinet/in.h>
#include <arpa/inet.h>
#include <sys/time.h>
#include <sys/socket.h>
#include <sys/types.h>

#define BANDWIDTH_LIMIT ((double)35 * (1 << 20))

long splice_pipe2socket_all(int pipe_in_fd, int sock_out_fd, size_t size){
    long len;
    size_t restsize = size;
    do {
        if((len = splice(pipe_in_fd, NULL
                         , sock_out_fd, NULL
                         , restsize, SPLICE_F_MOVE)) == -1){
            perror("splice error");
            exit(1);
        }
        if (len == 0){
            break;
        }
        restsize -= len;
    } while(restsize > 0);

    return size - restsize;
}

ssize_t recvall(int sock, char * buf, size_t size){
    ssize_t len;
    size_t restsize = size;
    do {
        if ((len = recv(sock, buf + (size - restsize), restsize, 0)) == -1){
            perror("recv error");
            exit(1);
        }
        if (len == 0){
            break;
        }
        restsize -= len;
    } while(restsize > 0);

    return size - restsize;
}

ssize_t sendall(int sock, char * buf, size_t size){
    ssize_t len;
    size_t restsize = size;
    do {
        if ((len = send(sock, buf + (size - restsize), restsize, 0)) == -1){
            perror("send error");
            exit(1);
        }
        if (len == 0){
            break;
        }
        restsize -= len;
    } while(restsize > 0);

    return size - restsize;
}

typedef struct string_buf {
    uint refcount;
    size_t size;
    size_t len;
    char * buf;
} string_buf_t;

string_buf_t * make_string_buf(size_t size){
    string_buf_t * ret;
    ret = malloc(sizeof(string_buf_t));
    if (posix_memalign(&ret->buf, 512, sizeof(char) * size) != 0){
        perror("posix_memalign error ");
        exit(1);
    }
    ret->refcount = 1;
    ret->size = size;
    ret->len = 0;

    return ret;
}

void free_string_buf(string_buf_t * sbuf){
    sbuf->refcount--;
    if (sbuf->refcount == 0){
        free(sbuf->buf);
        free(sbuf);
    }
}

void string_buf_refinc(string_buf_t * sbuf){
    sbuf->refcount++;
}

/* typedef struct queue_cell { */
/*     string_buf_t * sbuf; */
/*     size_t size; */
/* } queue_cell_t; */

typedef string_buf_t * queue_cell_t;

typedef struct queue {
    uint size;
    uint num;
    uint start_pos;
    uint end_pos;
    queue_cell_t * ringbuf;
    pthread_mutex_t lk;
    pthread_cond_t cond;
    pthread_spinlock_t slk;
    uint push_block_count;
    uint pop_block_count;
} queue_t;

queue_t * make_queue(uint size){
    queue_t * ret;
    ret = malloc(sizeof(queue_t));
    ret->size = size;
    ret->ringbuf = malloc(size * sizeof(queue_cell_t));
    ret->num = 0;
    ret->start_pos = 0;
    ret->end_pos = 0;
    ret->push_block_count = 0;
    ret->pop_block_count = 0;
    pthread_spin_init(&ret->slk, PTHREAD_PROCESS_PRIVATE);
    pthread_mutex_init(&ret->lk, NULL);
    pthread_cond_init(&ret->cond, NULL);

    return ret;
}

void queue_push(queue_t * q, string_buf_t * elem){
    // pthread_mutex_lock(&q->lk);
    pthread_spin_lock(&q->slk);
    while(q->size == q->num){
        q->push_block_count++;
        // pthread_cond_wait(&q->cond, &q->lk);
	pthread_spin_unlock(&q->slk);
	while(q->size == q->num){}
	pthread_spin_lock(&q->slk);
    }
    
    q->ringbuf[q->end_pos] = elem;
    q->end_pos++;
    if (q->end_pos >= q->size){
        q->end_pos = 0;
    }
    q->num++;
    // pthread_cond_signal(&q->cond);
    // pthread_mutex_unlock(&q->lk);
    pthread_spin_unlock(&q->slk);
}

queue_cell_t queue_pop(queue_t * q){
    queue_cell_t ret;
    // pthread_mutex_lock(&q->lk);
    pthread_spin_lock(&q->slk);
    while(q->num == 0){
        q->pop_block_count++;
        // pthread_cond_wait(&q->cond, &q->lk);
	pthread_spin_unlock(&q->slk);
	while(q->num == 0){}
	pthread_spin_lock(&q->slk);
    }

    ret = q->ringbuf[q->start_pos];
    q->start_pos++;
    if (q->start_pos >= q->size){
        q->start_pos = 0;
    }
    q->num --;
    assert(q->end_pos == (q->start_pos + q->num) % q->size);
    // pthread_cond_signal(&q->cond);
    // pthread_mutex_unlock(&q->lk);
    pthread_spin_unlock(&q->slk);
    return ret;
}

typedef enum {
    SOURCE,
    PIPER,
    DRAIN,
} role_t;

typedef enum {
    SUCCESS=0,
    FAILURE,
    OVERRUN,
} dd_status_t;

static char *dd_status_str[]=
{
"SUCCESS",
"FAILURE",
"OVERRUN",
};

typedef struct thread_arg {
    queue_t * q;
    int fd;
    dd_status_t status;
    uint64_t bytes_written;
} thread_arg_t;

void * dd_writer(void * arg){
    thread_arg_t * targ = (thread_arg_t *) arg;
    queue_t * q = targ->q;
    int output_fd = targ->fd;
    string_buf_t * qcell;
    long len;
    uint64_t total_size=0;
    dd_status_t status=SUCCESS;
    for(;;){
        qcell = queue_pop(q);
        if (qcell == NULL){ break; }
        if (status==SUCCESS){
            size_t btr=sizeof(char) * qcell->len;
            len = write(output_fd, qcell->buf, btr);
            if (len < 0 ){
                perror("write error");
                fprintf(stderr,"Give up writing to disk\n");
                status=FAILURE;
            }
            else if (len!=btr){
                fprintf(stderr,"write error: bytes to write/written mismatch (overrun?)\n");
                fprintf(stderr,"Give up writing to disk\n");
                total_size+=len;
                status=OVERRUN;
            }
            else{
                total_size+=len;
            }
        }
        free_string_buf(qcell);
    }
    close(output_fd);
    targ->status=status;
    targ->bytes_written=total_size;
    return NULL;
}

void * socket_sender(void * arg){
    thread_arg_t * targ = (thread_arg_t *) arg;
    queue_t * q = targ->q;
    int sock = targ->fd;
    string_buf_t * qcell;

    for(;;){
        qcell = queue_pop(q);
        if (qcell == NULL){ break; }
        sendall(sock, qcell->buf, qcell->size);
        free_string_buf(qcell);
    }

    return NULL;
}

inline double tv_diff(struct timeval t0, struct timeval t1){
    double ret;
    ret = t1.tv_sec + t1.tv_usec / 1000000.0 - (t0.tv_sec + t0.tv_usec / 1000000.0);
    return ret;
}

int main(int argc, char ** argv){
    int input_dd_pipe[2];
    int input_dd_fd = -1;
    int input_dd_pid = -1;
    int output_fd = -1;

    int listen_sock;
    int client_sock = -1;
    int forward_sock = -1;
    
    bool do_forward;
    bool do_output;

    char * opt_forward_addr = NULL;
    char * opt_input = NULL;
    char * opt_output = "/dev/null";
    int opt_limitbandwidth = 35;
    int opt_chunksize = 1024;
    int opt_port = 30303;
    char * opt_blocksize = "16k";
    char * opt_ddopt = "";
    bool opt_verbose = false;
    bool opt_extra_verbose = false;
    int opt_queuesize;
    role_t role = DRAIN;
    
    extern char * optarg;
    extern int optind, opterr;
    char ch;
    while((ch = getopt(argc, argv, "i:o:b:c:d:l:vw")) != -1){
        switch(ch){
        case 'i':
            opt_input = strdup(optarg);
            break;
        case 'o':
            opt_output = alloca(sizeof(char) * (strlen(optarg) + 1));
            strcpy(opt_output, optarg);
            break;
        case 'c':
            opt_chunksize = atoi(optarg);
            break;
        case 'b':
            opt_blocksize = alloca(sizeof(char) * (strlen(optarg) + 1));
            strcpy(opt_blocksize, optarg);
            break;
        case 'd':
            opt_ddopt = alloca(sizeof(char) * (strlen(optarg) + 1));
            strcpy(opt_ddopt, optarg);
            break;
        case 'p':
            opt_port = atoi(optarg);
            break;
        case 'l':
            opt_limitbandwidth = atoi(optarg);
            break;
        case 'v':
            opt_verbose = true;
            break;
        case 'w':
            opt_extra_verbose = true;
            break;
        }
    }
    argc -= optind;
    argv += optind;

    opt_queuesize = (1 << 29) / opt_chunksize;
    if (opt_queuesize == 0){
        opt_queuesize = 1;
    }

    fprintf(stderr, "option: input=%s, output=%s, verbse=%d, blocksize=%s, chunksize=%d, port=%d, queuesize=%d\n"
            , opt_input, opt_output, opt_verbose
            , opt_blocksize, opt_chunksize, opt_port, opt_queuesize);
    
    role = PIPER;
    if (argc < 1){
        if(opt_input != NULL){
            fprintf(stderr,
                    "Forwarding IP address is required if '-i' is specified\n");
            exit(1);
        }
        role = DRAIN;
    } else {
        opt_forward_addr = strdup(argv[0]);
        if(opt_input != NULL){
            role = SOURCE;
        }
    }
    
    do_forward = false;
    do_output = true;
    if (role == SOURCE){
        do_forward = true;
        do_output = false;
    }
    if (role == PIPER){
        do_forward = true;
    }

    if (role == SOURCE){
        if ((pipe(input_dd_pipe)) == -1){
            perror("Pipe error");
            exit(1);
        }
        pid_t pid;
        if ((pid = fork()) == 0){
            // child process
            dup2(input_dd_pipe[1], STDOUT_FILENO);
            close(input_dd_pipe[0]);

            char ** child_argv = alloca(sizeof(char *) * 5);
            char buf[1024];
            child_argv[0] = "dd";
            sprintf(buf, "if=%s", opt_input);
            child_argv[1] = strdup(buf);
            sprintf(buf, "bs=%s", opt_blocksize);
            child_argv[2] = strdup(buf);
            if (strlen(opt_ddopt) > 0){
                child_argv[3] = strdup(opt_ddopt);
            } else {
                child_argv[3] = NULL;
            }
            child_argv[4] = NULL;
            execvp("dd", child_argv);
        } else {
            close(input_dd_pipe[1]);
            input_dd_pid = pid;
            input_dd_fd = input_dd_pipe[0];
        }
    }
    if (role != SOURCE){
        if ((listen_sock = socket(PF_INET, SOCK_STREAM, IPPROTO_TCP)) == -1){
            perror("Listen socket failure");
            exit(1);
        }
        struct sockaddr_in bind_addr, client_addr;
        memset(&bind_addr, 0, sizeof(bind_addr));
        bind_addr.sin_port = htons(opt_port);
        bind_addr.sin_family = AF_INET;
        bind_addr.sin_addr.s_addr = htonl(INADDR_ANY);
        bind(listen_sock, (struct sockaddr*)&bind_addr, sizeof(bind_addr));
        if (listen(listen_sock, 1) == -1){
	    perror("Listen error");
            close(listen_sock);
	    exit(1);
	}
        puts("listen succeeded");
        fflush(stdout);
        socklen_t client_sockaddr_len = sizeof(client_addr);
        if ((client_sock = accept(listen_sock
                                  , (struct sockaddr*)&client_addr
                                  , &client_sockaddr_len)) == -1){
            close(listen_sock);
            perror("Accept error");
            exit(1);
        }
        puts("accept succeeded");
        fflush(stdout);
        shutdown(listen_sock, SHUT_RDWR);
        close(listen_sock);
    }

    if (do_forward == true){
        if ((forward_sock = socket(PF_INET, SOCK_STREAM, IPPROTO_TCP)) == -1){
            perror("Forward socket failure");
            exit(1);
        }
        struct sockaddr_in forward_addr;
        memset(&forward_addr, 0, sizeof(forward_addr));
        forward_addr.sin_port = htons(opt_port);
        forward_addr.sin_family = AF_INET;
        forward_addr.sin_addr.s_addr = inet_addr(opt_forward_addr);
        connect(forward_sock, (struct sockaddr*)&forward_addr, sizeof(forward_addr));
    }

    // queue_t * send_queue = make_queue(opt_queuesize);
    queue_t * dd_queue = make_queue(opt_queuesize);
    // pthread_t send_thread;
    pthread_t dd_thread;
    
    // thread_arg_t send_arg;
    if (do_output == true){
        output_fd = open(opt_output, O_WRONLY | O_DIRECT);
        if (output_fd == -1){
            perror("open error");
            if (do_forward == true){
                shutdown(forward_sock, SHUT_RDWR);
                close(forward_sock);
            }
            exit(1);
        }
    }
    thread_arg_t dd_arg;
    memset(&dd_arg,0,sizeof(dd_arg));
    if (do_output == true){
        dd_arg.q = dd_queue;
        dd_arg.fd = output_fd;
        pthread_create(&dd_thread, NULL, dd_writer, &dd_arg);
    }
    if (do_forward == true){
        // send_arg.q = send_queue;
        // send_arg.fd = forward_sock;
        // pthread_create(&send_thread, NULL, socket_sender, &send_arg);
    }

    struct timeval t0, t1, t_start;
    double recv_size = 0.0;
    uint64_t total_size = 0;

    // struct timeval probe_t0, probe_t1, probe_t2;
    // double net_time = 0.0;
    // double dd_time = 0.0;

    gettimeofday(&t0, NULL);
    t_start = t0;
    if (role == SOURCE){
        for(;;){
            long len = splice_pipe2socket_all(input_dd_fd
                                              , forward_sock
                                              , opt_chunksize);
            if (len == 0){
                break;
            }
            total_size += len;
            recv_size += len;
            
            gettimeofday(&t1, NULL);
            if (t1.tv_sec - t0.tv_sec > 5){
	        double delta = tv_diff(t0, t1);
                if (opt_verbose == true){
                    printf("net %f MB/sec\n"
			   , recv_size / delta / (1 << 20));
                    fflush(stdout);
                }
                t0 = t1;
                recv_size = 0;
            }
        }

        printf("[SORUCE] total sent size: %lld bytes\n", total_size);
        close(input_dd_fd);
    } else {
        assert(do_output == true);
        string_buf_t * recvbuf;

        printf("main loop\n");

        for(;;){
            recvbuf = make_string_buf(opt_chunksize);
            long len = recvall(client_sock, recvbuf->buf, recvbuf->size);
            recvbuf->len = len;
            if (len == 0){
                break;
            }
            if (do_forward == true){
                // string_buf_refinc(recvbuf);
                // queue_push(send_queue, recvbuf);
                sendall(forward_sock, recvbuf->buf, recvbuf->len);
            }
            total_size += len;
            recv_size += len;

            queue_push(dd_queue, recvbuf);

            gettimeofday(&t1, NULL);
            if (t1.tv_sec - t0.tv_sec > 2){
	        double delta = tv_diff(t0, t1);
                double push_blk = dd_queue->push_block_count / delta;
                
                if (opt_verbose == true){
                    printf("%0.f sec passed, total %.1f GB\n", tv_diff(t_start, t1), (double)total_size / (1 << 30));
                    printf("net %.1f MB/sec\npush blk %.2f /sec, pop blk %.2f /sec, queue num %d/%d\n"
			   , recv_size / delta / (1 << 20)
			   , push_blk
			   , dd_queue->pop_block_count / delta
			   , dd_queue->num, dd_queue->size);
                    puts("");
                    fflush(stdout);
                }

                t0 = t1;
                recv_size = 0;
                dd_queue->push_block_count = 0;
                dd_queue->pop_block_count = 0;
            }
        }
        queue_push(dd_queue, NULL);
        //printf("[%s] total sent size: %lld bytes\n", (role == PIPER ? "PIPER" : "DRAIN") ,total_size);
        // queue_push(send_queue, NULL);
    }

    if (do_forward){
        shutdown(forward_sock, SHUT_RDWR);
        close(forward_sock);
        // pthread_join(send_thread, NULL);
    }
    if (do_output == true){
        int retcode;
        pthread_join(dd_thread, NULL);
        retcode=((dd_arg.status==SUCCESS) && (dd_arg.bytes_written==total_size)) ? 0 : 1;
        if (dd_arg.bytes_written==total_size){
            printf("[%s][%s] total sent & written size: %lld bytes\n", (role == PIPER ? "PIPER" : "DRAIN") , dd_status_str[dd_arg.status], total_size);
        }
        else{
            printf("[%s][%s] total sent size: %lld bytes, written size: %lld bytes\n", (role == PIPER ? "PIPER" : "DRAIN") , dd_status_str[dd_arg.status], total_size, dd_arg.bytes_written);
        }
        return retcode;
    }

    return 0;
}
