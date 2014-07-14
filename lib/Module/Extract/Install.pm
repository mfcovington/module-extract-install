package Module::Extract::Install;
use strict;
use warnings;
use Carp;
use Module::Extract::Use;

our $VERSION = '0.1.0';

=head1 NAME

Module::Extract::Install - Install uninstalled modules explicitly
loaded by a Perl script or module

=head1 SYNOPSIS

    use Module::Extract::Install;

    my $installer = Module::Extract::Install->new;
    $installer->check_modules($file);

    my @uninstalled = $installer->not_installed;
    my @installed   = $installer->previously_installed;

    $installer->cpanm;

    my @newly_installed = $installer->newly_installed;
    my @failed_install  = $installer->failed_install;

=head1 DESCRIPTION

Extract the names of the modules explicitly loaded in a Perl script or
module and install them if they are not already installed. Since this
module relies on L<Module::Extract::Use|Module::Extract::Use>, it has
the same caveats regarding identifying loaded modules. Therefore,
modules that are loaded dynamically (e.g., C<eval "require $class">)
will not be installed.

=cut

=over 4

=item new

Makes an object. The object doesn't do anything just yet, but you need
it to call the methods.

=cut

sub new {
    my $class = shift;

    my $self = {
        _not_installed        => {},
        _previously_installed => {},
        _newly_installed      => {},
        _failed_install       => {},
    };
    bless $self, $class;

    return $self;
}

=item check_modules( FILE )

Analyzes FILE to generate a list of modules explicitly loaded in FILE
and identifies which are not currently installed.

=cut

sub check_modules {
    my ( $self, $file ) = @_;

    my $extractor = Module::Extract::Use->new;
    my $details   = $extractor->get_modules_with_details($file);

    # Temporary method for error handling:
    if ( $extractor->error ) {
        carp "Problem extracting modules used in $file";
    }

    for my $detail (@$details) {
        my $module  = $detail->module;
        my @imports = @{ $detail->imports };

        my $import_call = scalar @imports ? "$module qw(@imports)" : $module;

        eval "use $import_call;";
        if ($@) {
            $self->{_not_installed}{$module}++;
        }
        else {
            $self->{_previously_installed}{$module}++;
        }
    }
}

=item not_installed

Returns an alphabetical list of unique modules that were explicitly
loaded, but need to be installed. Modules are removed from this list
upon installation.

=cut

sub not_installed {
    my $self = shift;
    return sort keys %{ $self->{_not_installed} };
}

=item previously_installed

Returns an alphabetical list of unique installed modules that were
explicitly loaded.

=cut

sub previously_installed {
    my $self = shift;
    return sort keys %{ $self->{_previously_installed} };
}

=item newly_installed

Returns an alphabetical list of unique modules that were
explicitly loaded, needed to be installed, and were successfully
installed.

=cut

sub newly_installed {
    my $self = shift;
    return sort keys %{ $self->{_newly_installed} };
}

=item failed_install

Returns an alphabetical list of unique modules that were
explicitly loaded and needed to be installed, but whose installation
failed.

=cut

sub failed_install {
    my $self = shift;
    return sort keys %{ $self->{_failed_install} };
}

=item cpanm

Use cpanm to install loaded modules that are not currently installed.

=cut

sub cpanm {
    my $self = shift;

    my @modules = sort keys %{ $self->{_not_installed} };
    for (@modules) {
        my $exit_status = system("cpanm $_");
        if ($exit_status) {
            $self->{_failed_install}{$_}++;
        }
        else {
            delete $self->{_not_installed}{$_};
            delete $self->{_failed_install}{$_};
            $self->{_newly_installed}{$_}++;
        }
    }
}

=back

=head1 SEE ALSO

L<Module::Extract::Use|Module::Extract::Use>

=head1 SOURCE AVAILABILITY

The source code is on Github:
L<https://github.com/mfcovington/module-extract-install>

=head1 AUTHOR

Michael F. Covington <mfcovington@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2014, Michael F. Covington, All Rights Reserved.

You may redistribute this under the same terms as Perl itself.

=cut

1;
