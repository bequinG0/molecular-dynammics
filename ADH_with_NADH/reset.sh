#!/bin/bash
echo "Очистка всех сгенерированных файлов..."

# Удаляем координатные файлы
rm -f *.gro

# Удаляем топологии и их бекапы
rm -f *.top
rm -f *.top.*
rm -f *.itp
rm -f *.itp.*

# Удаляем логи
rm -f *.log

# Удаляем входные mdp-файлы (ions.mdp, minim.mdp, nvt.mdp, npt.mdp, md.mdp)
rm -f *.mdp

# Удаляем выделённые pdb (но не исходные 1mg5.pdb)
rm -f protein.pdb protein_with_act.pdb
rm -f nadh.pdb nadh_A.pdb nadh_B.pdb nadh_both.pdb
rm -f act.pdb
rm -f 1mg5_protein.pdb

# Удаляем специфические выходные файлы
rm -f complex.gro box.gro solv.gro solv_ions.gro
rm -f topol_*.itp posre*.itp nadh.itp

# Удаляем резервные копии, которые создаёт GROMACS и pdb2gmx
rm -f '#topol'* '#posre'* '#protein'* '#charmm'*
rm -f ./\#*

# Удаляем временные бэкапы исходного pdb (если остались)
rm -f 1mg5.pdb.bak 1mg5.pdb.tmp

echo "Готово. Остались только:"
ls -1
