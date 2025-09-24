#!/bin/bash

# Copyright 2023 Pascal Schmid
# Copyright 2011 Carl Anderson
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# The database schema and general approach have been taken from
# the following project by Carl Anderson:
# https://github.com/barabo/advanced-shell-history
# The rest of the code has been authored by Pascal Schmid.

# This program records Bash commands with additional context and stores them
# in an SQLite 3 database. The database replaces the ~/.bash_history file.
#
# This program depends on the following Debian GNU/Linux 12 (bookworm) packages:
# bash (required), sqlite3 (required), and fzf (optional)
#
# To use this program, source this script at the end of your ~/.bashrc file.


if [[ -d "${XDG_DATA_HOME:-$HOME/.local/share}" ]]
then
    GSCHECHTLI_DATABASE_FILE="${XDG_DATA_HOME:-$HOME/.local/share}/gschechtli.sqlite3"
else
    GSCHECHTLI_DATABASE_FILE="${HOME}/.gschechtli.sqlite3"
fi


if [[ ! -f "${GSCHECHTLI_DATABASE_FILE}" ]]
then
    sqlite3 -safe "${GSCHECHTLI_DATABASE_FILE}" <<'EOF'
CREATE TABLE sessions (
    id integer primary key autoincrement,
    hostname varchar(128),
    host_ip varchar(40),
    ppid int(5) not null,
    pid int(5) not null,
    time_zone str(3) not null,
    start_time integer not null,
    end_time integer,
    duration integer,
    tty varchar(20) not null,
    uid int(16) not null,
    euid int(16) not null,
    logname varchar(48),
    shell varchar(50) not null,
    sudo_user varchar(48),
    sudo_uid int(16),
    ssh_client varchar(60),
    ssh_connection varchar(100)
);

CREATE TABLE commands (
    id integer primary key autoincrement,
    session_id integer not null,
    shell_level integer not null,
    command_no integer,
    tty varchar(20) not null,
    euid int(16) not null,
    cwd varchar(256) not null,
    rval int(5) not null,
    start_time integer not null,
    end_time integer not null,
    duration integer not null,
    pipe_cnt int(3),
    pipe_vals varchar(80),
    command varchar(1000) not null,
    UNIQUE(session_id, command_no)
);
EOF
fi


if [[ -d "${XDG_CACHE_HOME:-$HOME/.cache}" ]]
then
    HISTFILE="${XDG_CACHE_HOME:-$HOME/.cache}/bash_history"
fi

HISTSIZE=""

HISTFILESIZE=""

HISTCONTROL=""

HISTTIMEFORMAT="%s "

shopt -s histappend


gschechtli_session()
{
    local gschechtli_hostname
    gschechtli_hostname="$( uname -n )"

    local gschechtli_pid="$$"

    local gschechtli_time_zone
    gschechtli_time_zone="$( date +'%:z %Z' )"

    local gschechtli_start_time
    gschechtli_start_time="$( date +%s )"

    local gschechtli_tty
    gschechtli_tty="$( tty )"

    GSCHECHTLI_SESSION_NUMBER="$( sqlite3 -safe "${GSCHECHTLI_DATABASE_FILE}" <<EOF
INSERT INTO sessions (
    hostname,
    ppid,
    pid,
    time_zone,
    start_time,
    tty,
    uid,
    euid,
    logname,
    shell,
    sudo_user,
    sudo_uid,
    ssh_client,
    ssh_connection
)
VALUES (
    '${gschechtli_hostname//\'/\'\'}',
    '${PPID//\'/\'\'}',
    '${gschechtli_pid//\'/\'\'}',
    '${gschechtli_time_zone//\'/\'\'}',
    '${gschechtli_start_time//\'/\'\'}',
    '${gschechtli_tty//\'/\'\'}',
    '${UID//\'/\'\'}',
    '${EUID//\'/\'\'}',
    '${LOGNAME//\'/\'\'}',
    '',
    '${SUDO_USER//\'/\'\'}',
    '${SUDO_UID//\'/\'\'}',
    '${SSH_CLIENT//\'/\'\'}',
    '${SSH_CONNECTION//\'/\'\'}'
)
RETURNING id;
EOF
)"
}

gschechtli_session


GSCHECHTLI_SKIP=1

builtin trap "GSCHECHTLI_SKIP=1" INT


GSCHECHTLI_PWD="${PWD}"


gschechtli_prompt_command()
{
    local previous_status="$1"
    local previous_pipestatus="$2"

    if [[ "${GSCHECHTLI_SKIP:-1}" == "1" ]]
    then
        GSCHECHTLI_SKIP=0
        return "${previous_status}"
    fi

    local entry
    entry="$( builtin history 1 )"
    entry="${entry#"${entry%%[![:space:]]*}"}"
    local previous_number="${entry%%[![:digit:]]*}"
    entry="${entry#"${entry%%[![:digit:]]*}"}"
    entry="${entry#"${entry%%[![:space:]]*}"}"
    local previous_timestamp="${entry%%[![:digit:]]*}"
    entry="${entry#"${entry%%[![:digit:]]*}"}"
    local previous_command="${entry# }"

    builtin history -a

    local gschechtli_tty
    gschechtli_tty="$( tty )"

    sqlite3 -safe "${GSCHECHTLI_DATABASE_FILE}" <<EOF
INSERT OR IGNORE INTO commands
(
    session_id,
    shell_level,
    command_no,
    tty,
    euid,
    cwd,
    rval,
    start_time,
    end_time,
    duration,
    pipe_vals,
    command
)
VALUES (
    '${GSCHECHTLI_SESSION_NUMBER//\'/\'\'}',
    '${SHLVL//\'/\'\'}',
    '${previous_number//\'/\'\'}',
    '${gschechtli_tty//\'/\'\'}',
    '${EUID//\'/\'\'}',
    '${GSCHECHTLI_PWD//\'/\'\'}',
    '${previous_status//\'/\'\'}',
    '${previous_timestamp//\'/\'\'}',
    $( date +%s ),
    0,
    '${previous_pipestatus//\'/\'\'}',
    '${previous_command//\'/\'\'}'
)
;
EOF

    GSCHECHTLI_PWD="${PWD}"

    # The PIPESTATUS variable is preserved.

    return "${previous_status}"
}

PROMPT_COMMAND="gschechtli_prompt_command \"\${?}\" \"\${PIPESTATUS[*]}\"${PROMPT_COMMAND:+" ; ${PROMPT_COMMAND}"}"
# PROMPT_COMMAND="${PROMPT_COMMAND:+"${PROMPT_COMMAND} ; "}gschechtli_prompt_command \"\${?}\" \"\${PIPESTATUS[*]}\""
# PROMPT_COMMAND="gschechtli_prompt_command \"\${?}\" \"\${PIPESTATUS[*]}\""


gschechtli_trap_exit_and_term()
{
    gschechtli_prompt_command "$1" "$2"
    sqlite3 -safe "${GSCHECHTLI_DATABASE_FILE}" "UPDATE sessions SET end_time = $( date +%s ) WHERE id = ${GSCHECHTLI_SESSION_NUMBER} ;"
    return "$1"
}

builtin trap "gschechtli_trap_exit_and_term \"\${?}\" \"\${PIPESTATUS[*]}\"" EXIT TERM


gschechtli_history_search()
{
    local query
    query=''

    query+=" SELECT trimmed_command FROM ( "
    query+=" SELECT trim(command) AS trimmed_command, MAX(start_time) FROM commands "
    # ${VARIABLE//PATTERN/REPLACEMENT}
    query+=" WHERE commands.cwd = '${PWD//\'/\'\'}' "
    query+=" AND commands.tty != 'not a tty' "
    query+=" GROUP BY trimmed_command ORDER BY start_time DESC "
    query+=" ) "

    local command
    command="$( sqlite3 -readonly -safe "${GSCHECHTLI_DATABASE_FILE}" "${query}" | fzf )"
    if [ -n "${command}" ]; then
        echo "${command}"
    fi
}


# https://superuser.com/a/1662149
gschechtli_history_prompt()
{
    local history_entry
    history_entry="$( gschechtli_history_search "$1" )"
    if [[ -n "${history_entry}" ]]
    then
        READLINE_POINT=0
        READLINE_LINE=""
        READLINE_LINE="${history_entry}"
        READLINE_POINT="${#READLINE_LINE}"
    fi
}

if [[ -x /usr/bin/fzf ]]
then
    builtin bind -x '"\e[A": "gschechtli_history_prompt"'
fi
