use inc::Module::Install;
name 'Net-AppNotifications';
all_from 'lib/Net/AppNotifications.pm';

build_requires 'Test::More';
use_test_base;
auto_include_deps;
author_tests('xt');
auto_set_repository;
WriteAll;
