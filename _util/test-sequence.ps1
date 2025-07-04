
$portableBaseName = 'strawberry-perl-5.40.2.1-64bit-portable'

& "C:\_test\perl-bulk-module-installer\StrawberryPortable_a_Extract.ps1" -StrawberryZip "C:\_test\$portableBaseName.zip" -Destination "C:\_test\$portableBaseName"
& "C:\_test\perl-bulk-module-installer\StrawberryPortable_b_AddDefenderExclude.ps1" -StrawberryDir "C:\_test\$portableBaseName"
& "C:\_test\perl-bulk-module-installer\StrawberryPortable_c_CpanL_ListModules.ps1" -StrawberryDir "C:\_test\$portableBaseName" -ModuleListFileTxt "C:\_test\perl-bulk-module-installer\log\_list_before.txt"
& "C:\_test\perl-bulk-module-installer\StrawberryPortable_d_InstallModules.ps1" -StrawberryDir "C:\_test\$portableBaseName" -InstallModuleListFile "C:\_test\perl-bulk-module-installer\test-module-lists\SingleModuleExample.txt" -DontTryModuleListFile "C:\_test\perl-bulk-module-installer\test-module-lists\_dont_try_modules.txt"
& "C:\_test\perl-bulk-module-installer\StrawberryPortable_d_InstallModules.ps1" -StrawberryDir "C:\_test\$portableBaseName" -InstallModuleListFile "C:\_test\perl-bulk-module-installer\test-module-lists\SmallModuleExample.txt" -DontTryModuleListFile "C:\_test\perl-bulk-module-installer\test-module-lists\_dont_try_modules.txt"
& "C:\_test\perl-bulk-module-installer\StrawberryPortable_d_InstallModules.ps1" -StrawberryDir "C:\_test\$portableBaseName" -InstallModuleListFile "C:\_test\perl-bulk-module-installer\test-module-lists\SingleModuleExample.txt", "C:\_test\perl-bulk-module-installer\test-module-lists\SmallModuleExample.txt" -DontTryModuleListFile "C:\_test\perl-bulk-module-installer\test-module-lists\_dont_try_modules.txt"
& "C:\_test\perl-bulk-module-installer\StrawberryPortable_c_CpanL_ListModules.ps1" -StrawberryDir "C:\_test\$portableBaseName" -ModuleListFileTxt "C:\_test\perl-bulk-module-installer\log\_list_after.txt"
& "C:\_test\perl-bulk-module-installer\StrawberryPortable_e_RemoveDefenderExclude.ps1" -StrawberryDir "C:\_test\$portableBaseName"
& "C:\_test\perl-bulk-module-installer\StrawberryPortable_f_RunDefenderScan.ps1" -StrawberryDir "C:\_test\$portableBaseName"
& "C:\_test\perl-bulk-module-installer\StrawberryPortable_d_Package.ps1" -StrawberryDir "C:\_test\$portableBaseName"

& "C:\_test\perl-bulk-module-installer\StrawberryPortable_c_CpanL_ListModules.ps1" -StrawberryDir "C:\_test\strawberry-perl-5.24.4.1-64bit-portable" -ModuleListFileTxt "C:\_test\perl-bulk-module-installer\log\_list_5.24.4.1.txt"
& "C:\_test\perl-bulk-module-installer\StrawberryPortable_c_CpanL_ListModules.ps1" -StrawberryDir "C:\_test\strawberry-perl-5.26.3.1-64bit-portable" -ModuleListFileTxt "C:\_test\perl-bulk-module-installer\log\_list_5.26.3.1.txt"
& "C:\_test\perl-bulk-module-installer\StrawberryPortable_c_CpanL_ListModules.ps1" -StrawberryDir "C:\_test\strawberry-perl-5.28.2.1-64bit-portable" -ModuleListFileTxt "C:\_test\perl-bulk-module-installer\log\_list_5.28.2.1.txt"
& "C:\_test\perl-bulk-module-installer\StrawberryPortable_c_CpanL_ListModules.ps1" -StrawberryDir "C:\_test\strawberry-perl-5.30.3.1-64bit-portable" -ModuleListFileTxt "C:\_test\perl-bulk-module-installer\log\_list_5.30.3.1.txt"
& "C:\_test\perl-bulk-module-installer\StrawberryPortable_c_CpanL_ListModules.ps1" -StrawberryDir "C:\_test\strawberry-perl-5.32.1.1-64bit-portable" -ModuleListFileTxt "C:\_test\perl-bulk-module-installer\log\_list_5.32.1.1.txt"
& "C:\_test\perl-bulk-module-installer\StrawberryPortable_c_CpanL_ListModules.ps1" -StrawberryDir "C:\_test\strawberry-perl-5.34.3.1-64bit-portable" -ModuleListFileTxt "C:\_test\perl-bulk-module-installer\log\_list_5.34.3.1.txt"
& "C:\_test\perl-bulk-module-installer\StrawberryPortable_c_CpanL_ListModules.ps1" -StrawberryDir "C:\_test\strawberry-perl-5.36.3.1-64bit-portable" -ModuleListFileTxt "C:\_test\perl-bulk-module-installer\log\_list_5.36.3.1.txt"
& "C:\_test\perl-bulk-module-installer\StrawberryPortable_c_CpanL_ListModules.ps1" -StrawberryDir "C:\_test\strawberry-perl-5.38.4.1-64bit-portable" -ModuleListFileTxt "C:\_test\perl-bulk-module-installer\log\_list_5.38.4.1.txt"
& "C:\_test\perl-bulk-module-installer\StrawberryPortable_c_CpanL_ListModules.ps1" -StrawberryDir "C:\_test\strawberry-perl-5.40.2.1-64bit-portable" -ModuleListFileTxt "C:\_test\perl-bulk-module-installer\log\_list_5.40.2.1.txt"

& "C:\_test\perl-bulk-module-installer\CompareModuleListCsv.ps1" -ListA "C:\_test\perl-bulk-module-installer\log\_list_5.40.2.1.csv" -ListB "C:\_test\perl-bulk-module-installer\log\_list_5.38.4.1.csv"

& "C:\_test\perl-bulk-module-installer\CompareModuleListCsv.ps1" -ListA "C:\_test\perl-bulk-module-installer\log\_list_5.24.4.1.csv" -ListB "C:\_test\perl-bulk-module-installer\log\_list_5.26.3.1.csv" -CompareResultList "C:\_test\perl-bulk-module-installer\log\_list_5.24_vs_5.26.csv"
