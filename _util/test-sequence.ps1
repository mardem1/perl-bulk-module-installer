
$portableBaseName = 'strawberry-perl-5.40.2.1-64bit-portable'
$baseDir = 'C:\perl-build'

& "$baseDir\perl-bulk-module-installer\StrawberryPortable_a_Extract.ps1" -StrawberryZip "$baseDir\$portableBaseName.zip" -Destination "$baseDir\$portableBaseName"
& "$baseDir\perl-bulk-module-installer\StrawberryPortable_b_AddDefenderExclude.ps1" -StrawberryDir "$baseDir\$portableBaseName"
& "$baseDir\perl-bulk-module-installer\StrawberryPortable_c_CpanL_ListModules.ps1" -StrawberryDir "$baseDir\$portableBaseName" -ModuleListFileTxt "$baseDir\perl-bulk-module-installer\log\_list_before.txt"
& "$baseDir\perl-bulk-module-installer\StrawberryPortable_d_InstallModules.ps1" -StrawberryDir "$baseDir\$portableBaseName" -InstallModuleListFile "$baseDir\perl-bulk-module-installer\test-module-lists\SingleModuleExample.txt" -DontTryModuleListFile "$baseDir\perl-bulk-module-installer\test-module-lists\_dont_try_modules.txt"
& "$baseDir\perl-bulk-module-installer\StrawberryPortable_d_InstallModules.ps1" -StrawberryDir "$baseDir\$portableBaseName" -InstallModuleListFile "$baseDir\perl-bulk-module-installer\test-module-lists\SmallModuleExample.txt" -DontTryModuleListFile "$baseDir\perl-bulk-module-installer\test-module-lists\_dont_try_modules.txt"
& "$baseDir\perl-bulk-module-installer\StrawberryPortable_d_InstallModules.ps1" -StrawberryDir "$baseDir\$portableBaseName" -InstallModuleListFile "$baseDir\perl-bulk-module-installer\test-module-lists\SingleModuleExample.txt", "$baseDir\perl-bulk-module-installer\test-module-lists\SmallModuleExample.txt" -DontTryModuleListFile "$baseDir\perl-bulk-module-installer\test-module-lists\_dont_try_modules.txt"
& "$baseDir\perl-bulk-module-installer\StrawberryPortable_c_CpanL_ListModules.ps1" -StrawberryDir "$baseDir\$portableBaseName" -ModuleListFileTxt "$baseDir\perl-bulk-module-installer\log\_list_after.txt"
& "$baseDir\perl-bulk-module-installer\StrawberryPortable_e_RemoveDefenderExclude.ps1" -StrawberryDir "$baseDir\$portableBaseName"
& "$baseDir\perl-bulk-module-installer\StrawberryPortable_f_RunDefenderScan.ps1" -StrawberryDir "$baseDir\$portableBaseName"
& "$baseDir\perl-bulk-module-installer\StrawberryPortable_g_Optimize.ps1" -StrawberryDir "$baseDir\$portableBaseName" -MergeLibs
& "$baseDir\perl-bulk-module-installer\StrawberryPortable_h_Package.ps1" -StrawberryDir "$baseDir\$portableBaseName"

& "$baseDir\perl-bulk-module-installer\StrawberryPortable_c_CpanL_ListModules.ps1" -StrawberryDir "$baseDir\strawberry-perl-5.24.4.1-64bit-portable" -ModuleListFileTxt "$baseDir\perl-bulk-module-installer\log\_list_5.24.4.1.txt"
& "$baseDir\perl-bulk-module-installer\StrawberryPortable_c_CpanL_ListModules.ps1" -StrawberryDir "$baseDir\strawberry-perl-5.26.3.1-64bit-portable" -ModuleListFileTxt "$baseDir\perl-bulk-module-installer\log\_list_5.26.3.1.txt"
& "$baseDir\perl-bulk-module-installer\StrawberryPortable_c_CpanL_ListModules.ps1" -StrawberryDir "$baseDir\strawberry-perl-5.28.2.1-64bit-portable" -ModuleListFileTxt "$baseDir\perl-bulk-module-installer\log\_list_5.28.2.1.txt"
& "$baseDir\perl-bulk-module-installer\StrawberryPortable_c_CpanL_ListModules.ps1" -StrawberryDir "$baseDir\strawberry-perl-5.30.3.1-64bit-portable" -ModuleListFileTxt "$baseDir\perl-bulk-module-installer\log\_list_5.30.3.1.txt"
& "$baseDir\perl-bulk-module-installer\StrawberryPortable_c_CpanL_ListModules.ps1" -StrawberryDir "$baseDir\strawberry-perl-5.32.1.1-64bit-portable" -ModuleListFileTxt "$baseDir\perl-bulk-module-installer\log\_list_5.32.1.1.txt"
& "$baseDir\perl-bulk-module-installer\StrawberryPortable_c_CpanL_ListModules.ps1" -StrawberryDir "$baseDir\strawberry-perl-5.34.3.1-64bit-portable" -ModuleListFileTxt "$baseDir\perl-bulk-module-installer\log\_list_5.34.3.1.txt"
& "$baseDir\perl-bulk-module-installer\StrawberryPortable_c_CpanL_ListModules.ps1" -StrawberryDir "$baseDir\strawberry-perl-5.36.3.1-64bit-portable" -ModuleListFileTxt "$baseDir\perl-bulk-module-installer\log\_list_5.36.3.1.txt"
& "$baseDir\perl-bulk-module-installer\StrawberryPortable_c_CpanL_ListModules.ps1" -StrawberryDir "$baseDir\strawberry-perl-5.38.4.1-64bit-portable" -ModuleListFileTxt "$baseDir\perl-bulk-module-installer\log\_list_5.38.4.1.txt"
& "$baseDir\perl-bulk-module-installer\StrawberryPortable_c_CpanL_ListModules.ps1" -StrawberryDir "$baseDir\strawberry-perl-5.40.2.1-64bit-portable" -ModuleListFileTxt "$baseDir\perl-bulk-module-installer\log\_list_5.40.2.1.txt"

& "$baseDir\perl-bulk-module-installer\CompareModuleListCsv.ps1" -ListA "$baseDir\perl-bulk-module-installer\log\_list_5.40.2.1.csv" -ListB "$baseDir\perl-bulk-module-installer\log\_list_5.38.4.1.csv"

& "$baseDir\perl-bulk-module-installer\CompareModuleListCsv.ps1" -ListA "$baseDir\perl-bulk-module-installer\log\_list_5.24.4.1.csv" -ListB "$baseDir\perl-bulk-module-installer\log\_list_5.26.3.1.csv" -CompareResultList "$baseDir\perl-bulk-module-installer\log\_list_5.24_vs_5.26.csv"
