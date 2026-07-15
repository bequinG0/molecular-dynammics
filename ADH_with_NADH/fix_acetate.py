#!/usr/bin/env python3
"""
fix_acetate.py
Переименовывает остаток ACT -> ACET и правит имена атомов
в соответствии с CHARMM36 (C1, C2, O1, O2, H1, H2, H3).
Создаёт резервную копию с расширением .bak.
"""
import sys
import fileinput
import os

def fix_acetate(pdb_file):
    # Словарь для переименования атомов:
    # Старое имя (из PDB) -> Новое имя (ожидаемое CHARMM36)
    atom_map = {
        'CH3': 'C1',   # метильный углерод
        'C':   'C2',   # карбоксильный углерод
        'O':   'O1',   # кислород (один из двух)
        'OXT': 'O2',   # концевой кислород
        # Если водороды названы по-другому, добавь сюда:
        # 'H1': 'H1',  # уже правильно
        # 'H2': 'H2',
        # 'H3': 'H3',
    }

    # Проверяем, есть ли файл
    if not os.path.isfile(pdb_file):
        print(f"Ошибка: файл {pdb_file} не найден.")
        sys.exit(1)

    # Делаем резервную копию
    backup = pdb_file + '.bak'
    print(f"Создаю резервную копию: {backup}")
    os.system(f'cp {pdb_file} {backup}')

    print(f"Обрабатываю файл: {pdb_file}")
    with fileinput.FileInput(pdb_file, inplace=True, backup='.tmp') as f:
        for line in f:
            # Работаем только со строками ATOM и HETATM
            if line.startswith(('ATOM', 'HETATM')) and len(line) >= 22:
                # Извлекаем имя остатка (столбцы 18-20, индексы 17-19)
                resname = line[17:20]
                
                if resname == 'ACT':
                    # Заменяем ACT -> ACET
                    line = line[:17] + 'ACET' + line[21:]

                    # Извлекаем имя атома (столбцы 13-16, индексы 12-16)
                    atom_name = line[12:16].strip()
                    
                    # Если атом есть в словаре — переименовываем
                    if atom_name in atom_map:
                        new_name = atom_map[atom_name]
                        # Записываем новое имя (4 символа, выравнивание вправо)
                        line = line[:12] + new_name.rjust(4) + line[16:]
            
            # Выводим строку (в файл)
            sys.stdout.write(line)

    print("Готово! Файл обновлён.")
    print(f"Резервная копия сохранена как {backup}")

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print("Использование: python3 fix_acetate.py <файл.pdb>")
        sys.exit(1)
    fix_acetate(sys.argv[1])
