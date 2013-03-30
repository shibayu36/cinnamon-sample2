use strict;
use warnings;

# Exports some commands
use Cinnamon::DSL;

my $application = 'cinnamon-sample2';

# It's required if you want to login to remote host
set user => 'vagrant';

# User defined params to use later
set application => $application;
set repository  => 'git://github.com/shibayu36/cinnamon-sample2.git';

set current_dir => sub {
    return get('deploy_to') . '/current';
};

set releases_dir => sub {
    return get('deploy_to') . '/releases';
};

set cpan_lib => '/home/app/lib/grepan';

role production => ['cinnamon-web1', 'cinnamon-web2', 'cinnamon-web3'], {
    deploy_to         => "/home/vagrant/$application",
    branch            => "master",
    daemontools_dir   => "/service/$application",
    run_script_prefix => "production",
};

task 'directory' => sub {
    my ($host, @args) = @_;
    remote {
        run "ls /home/vagrant/cinnamon-sample2/releases";
    } $host;
};

# Tasks
task update => sub {
    my ($host, @args) = @_;
    my $deploy_to    = get('deploy_to');
    my $release_path = get('releases_dir');
    my $current_path = get('current_dir');
    my $current_release = $release_path . "/" . time;

    my $branch       = "origin/" . get('branch');
    my $repository   = get 'repository';

    # Executed on remote host
    remote {
        run "git clone --depth 0 $repository $current_release";
        run "cd $current_release && git fetch origin && git checkout -q $branch && git submodule update --init";
        run "ln -nsf $current_release $current_path";

        # delete old release
        my ($stdout) = run "ls -x $release_path";
        my $releases = [sort {$b <=> $a} split /\s+/, $stdout];
        return if scalar @$releases < 5;

        my @olds = splice @$releases, 5;
        for my $dir (@olds) {
            run "rm -rf $deploy_to/releases/$dir";
        }
    } $host;
};

task daemontools => {
    setup => sub {
        my ($host, @args) = @_;
        my $run_script_prefix = get('run_script_prefix') || '';
        my $daemontools_dir   = get('daemontools_dir');
        my $current_path      = get('current_dir');

        remote {
            sudo "mkdir -p $daemontools_dir/log/main";
            sudo "ln -sf $current_path/bin/$run_script_prefix.run.sh $daemontools_dir/run";
            sudo "ln -sf $current_path/bin/$run_script_prefix.log.run.sh $daemontools_dir/log/run";
            sudo "chown -R app:app $daemontools_dir/log";
        } $host;
    },
    start => sub {
        my ($host, @args) = @_;
        my $daemontools_dir = get('daemontools_dir');

        remote {
            sudo "svc -u $daemontools_dir";
        } $host;
    },
    stop => sub {
        my ($host, @args) = @_;
        my $daemontools_dir = get('daemontools_dir');

        remote {
            sudo "svc -d $daemontools_dir";
        } $host;
    },
    restart => sub {
        my ($host, @args) = @_;
        my $daemontools_dir = get('daemontools_dir');

        remote {
            sudo "svc -t $daemontools_dir";
        } $host;
    },
};

task cron => {
    list => sub {
        my ($host, @args) = @_;
        remote {
            sudo q{/bin/bash -c 'for file in $(ls /etc/cron.d/); do echo "# $file"; cat "/etc/cron.d/$file"; echo; done'};
        } $host;
    },

    update => sub {
        my ($host, @args) = @_;
        my $current = get('current_dir');
        remote {
            sudo "cp -v $current/config/cron.d/* /etc/cron.d/";
            sudo 'chown -R root:root /etc/cron.d/';
            sudo 'chmod -R 0644 /etc/cron.d/';
            sudo 'chmod 0700 /etc/cron.d/';
        } $host;
    },

    reload => sub {
        my ($host, @args) = @_;
        remote {
            sudo '/etc/init.d/crond reload';
        } $host;
    },
};

task installdeps => sub {
    my ($host, @args) = @_;
    my $current  = get('current_dir');
    my $cpan_lib = get('cpan_lib');

    remote {
        run "mkdir -p $cpan_lib";
        run "cd $current && cpanm --verbose -L $cpan_lib --installdeps . < /dev/null; true";
    } $host;
};
