#!/usr/bin/env perl 
use strict;
use warnings;

use HTTP::Tiny;
use JSON::MaybeXS qw(decode_json);
use Time::HiRes qw(usleep);
use OptArgs2;
use threads;

opt marathon => (
    isa      => 'Str',
    required => 1,
    comment  => 'marathon URL',
);

opt lb => (
    isa     => 'ArrayRef',
    comment => 'marathon-lb node - test direct this load balancer',
);

opt count => (
    isa          => 'Int',
    default      => 100,
    show_default => 1,
    comment      => 'Count of requests to one app',
);

opt max_usleep => (
    isa          => 'Int',
    default      => 10_000,
    show_default => 1,
    comment      => 'maximal micro-sleep between requests to app',
);

opt verbose => (
    isa     => 'Flag',
    alias   => 'v',
    comment => 'print verbose information of process',
);

my $optargs = optargs;

unshift @{ $optargs->{lb} }, undef;

my $http = HTTP::Tiny->new(keep_alive => 0,);

my $res = $http->get("$optargs->{marathon}/v2/apps");
if (!$res->{success}) {
    die;
}

my $apps = decode_json($res->{content});

printf "Found %d apps in marathon\n", scalar @{$apps->{apps}} if $optargs->{verbose};

foreach my $app (@{ $apps->{apps} }) {
    threads->create(\&process_of_one_app, $http, $app);
}

foreach my $thr (threads->list()) {
    $thr->join();
}

sub process_of_one_app {
    my ($http, $app) = @_;

    my $id = $app->{id};

    if (!$app->{instances}) {
        print "#$id - not instances\n" if $optargs->{verbose};
        return;
    }

    my @urls;
    foreach my $label (keys %{ $app->{labels} }) {
        if ($label =~ /^HAPROXY_\d+_VHOST/) {
            foreach my $url (split ',', $app->{labels}{$label}) {
                foreach my $peer (@{ $optargs->{lb} }) {
                    push @urls,
                      {
                        host => $url,
                        peer => $peer,
                      };
                }
            }
        }
    }

    if (!scalar @urls) {
        print "#$id - no vhost set\n" if $optargs->{verbose};
        return;
    }

    my $tasks_res = $http->get("$optargs->{marathon}/v2/apps/$id/tasks");
    if (!$tasks_res->{success}) {
        die "No task $id info";
    }
    my $tasks = decode_json($tasks_res->{content});

    foreach my $task (@{ $tasks->{tasks} }) {
        push @urls, map { { host => "$task->{host}:$_" } } @{ $task->{ports} };
    }

    my %responsegram;
    foreach my $url_set (@urls) {
        my $url      = $url_set->{host};
        my $peer     = $url_set->{peer} || undef;
        my $p_peer   = defined $peer ? " ($peer)" : "";
        my $url_peer = "${url}${p_peer}";

        foreach my $i (1 .. $optargs->{count}) {

            $url = "http://$url" unless $url =~ /^http:/;
            my $res = $http->request('GET', $url, { peer => $peer });

            $responsegram{$url_peer}{ $res->{status} }++;

            usleep(rand $optargs->{max_usleep});
        }
    }

    print_responsegram($id, \%responsegram);
}

sub print_responsegram {
    my ($id, $histogram) = @_;

    print "$id\n";
    foreach my $url_peer (sort keys %$histogram) {
        print "\t$url_peer\n";
        foreach my $key (sort { $a <=> $b } keys %{ $histogram->{$url_peer} }) {
            print "\t\tstatus $key: $histogram->{$url_peer}{$key}x\n";
        }
    }
}
