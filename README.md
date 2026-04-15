# 校园活动报名与共享物资调配管理系统

一个基于 Flask + MySQL 的课程项目，覆盖活动发布、报名签到、物资借还、统计查询，并扩展了二手交易与校园社区模块。

数据库内容核心包含：
- 事务删除
- 触发器校验
- 存储过程联动更新
- 视图聚合查询

## 目录

- [项目亮点](#项目亮点)
- [技术栈](#技术栈)
- [项目结构](#项目结构)
- [快速开始](#快速开始)
- [数据库初始化顺序](#数据库初始化顺序)
- [默认演示账号](#默认演示账号)
- [功能清单](#功能清单)
- [常见问题](#常见问题)
- [安全说明](#安全说明)
- [后续可扩展方向](#后续可扩展方向)

## 项目亮点

1. 角色化系统：admin、club、student 三类角色。
2. 活动全流程：创建、发布、报名、签到、结算、删除（含事务保护）。
3. 物资借还闭环：借用单、借用明细、库存扣减与归还回补。
4. 统计视图：直接基于数据库视图展示综合统计与热门活动。
5. 扩展模块：
   - 二手交易（商品、订单、状态流转）
   - 校园社区（发帖、评论、点赞）
6. 前后端分层清晰：core + routes + templates + sql。

## 技术栈

- 后端：Python 3.10+、Flask 3.0
- 数据库：MySQL 8.0+
- 数据库连接：PyMySQL
- 前端：Jinja2 + HTML + CSS

## 项目结构

~~~text
aaSQL-project/
├─ app.py                       # Flask 启动入口（默认端口 5001）
├─ config.py                    # 配置（支持环境变量覆盖）
├─ requirements.txt             # Python 依赖
├─ core/
│  ├─ auth.py                   # 登录态、权限装饰器、用户上下文
│  └─ db.py                     # 数据库连接管理
├─ routes/
│  ├─ auth_routes.py            # 登录/注册/退出
│  ├─ home_routes.py            # 首页与“我的中心”
│  ├─ activity_routes.py        # 活动与报名签到
│  ├─ borrow_routes.py          # 借用与归还
│  ├─ trade_routes.py           # 二手交易
│  ├─ community_routes.py       # 社区帖子/评论/点赞
│  └─ stats_routes.py           # 统计页
├─ templates/                   # 页面模板
├─ static/css/                  # 样式文件
└─ sql/
   ├─ 01_create_database.sql
   ├─ 02_create_tables.sql
   ├─ 03_insert_init_data.sql
   ├─ 04_trigger.sql
   ├─ 05_procedure.sql
   ├─ 06_view.sql
   ├─ 07_event.sql
   ├─ 08_add_trade_community.sql
   └─ 09_add_post_like.sql
~~~

## 快速开始

### 1) 克隆项目

~~~bash
git clone https://github.com/Skylar-Jiang/Campus-Know-It-All
~~~

### 2) 创建并激活虚拟环境

Windows PowerShell：

~~~powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
~~~

Windows CMD：

~~~bat
python -m venv .venv
.venv\Scripts\activate.bat
~~~

macOS/Linux：

~~~bash
python3 -m venv .venv
source .venv/bin/activate
~~~

### 3) 安装依赖

~~~bash
pip install -r requirements.txt
~~~

### 4) 配置数据库连接

项目默认读取以下环境变量（也可直接改 config.py）：

- SECRET_KEY
- DB_HOST
- DB_PORT
- DB_USER
- DB_PASSWORD
- DB_NAME

推荐在本地设置环境变量后再启动。

Windows PowerShell 示例：

~~~powershell
$env:DB_HOST="127.0.0.1"
$env:DB_PORT="3306"
$env:DB_USER="root"
$env:DB_PASSWORD="你的MySQL密码"
$env:DB_NAME="campus_activity_db"
$env:SECRET_KEY="replace-with-your-secret"
~~~

macOS/Linux 示例：

~~~bash
export DB_HOST=127.0.0.1
export DB_PORT=3306
export DB_USER=root
export DB_PASSWORD=你的MySQL密码
export DB_NAME=campus_activity_db
export SECRET_KEY=replace-with-your-secret
~~~

### 5) 初始化数据库

方式 A（推荐）：在 MySQL 客户端依次执行脚本。

~~~sql
source sql/01_create_database.sql;
source sql/02_create_tables.sql;
source sql/03_insert_init_data.sql;
source sql/04_trigger.sql;
source sql/05_procedure.sql;
source sql/06_view.sql;
source sql/07_event.sql;
source sql/08_add_trade_community.sql;
source sql/09_add_post_like.sql;
~~~

方式 B：使用 GUI（如 MySQL Workbench）按同样顺序逐个运行。

### 6) 启动项目

~~~bash
python app.py
~~~

启动成功后访问：

- http://127.0.0.1:5001

说明：项目默认使用 5001 端口，避免占用常见的 5000 端口。

## 数据库初始化顺序

请严格按顺序执行，避免对象依赖错误：

1. 01_create_database.sql
2. 02_create_tables.sql
3. 03_insert_init_data.sql
4. 04_trigger.sql
5. 05_procedure.sql
6. 06_view.sql
7. 07_event.sql
8. 08_add_trade_community.sql
9. 09_add_post_like.sql

执行后可快速检查：

~~~sql
SHOW TRIGGERS;
SHOW PROCEDURE STATUS WHERE Db='campus_activity_db';
SHOW FULL TABLES WHERE TABLE_TYPE='VIEW';
SHOW EVENTS;
~~~

## 默认演示账号

执行 sql/03_insert_init_data.sql 后可使用以下账号（密码均为 123456）：

- 管理员：admin1
- 社团负责人：club_music
- 社团负责人：club_volunteer
- 学生：stu_zhang
- 学生：stu_li
- 学生：stu_wang
- 学生：stu_zhao

## 功能清单

### 核心模块

- 用户与角色管理
- 活动管理
- 活动报名与签到
- 共享物资借用与归还
- 活动综合统计

### 扩展模块

- 二手交易
  - 商品发布、浏览、详情
  - 下单锁定
  - 订单状态流转（created/cancelled/completed）
- 校园社区
  - 帖子列表与详情
  - 评论
  - 点赞（依赖 sql/09_add_post_like.sql）

## 常见问题

### 1. 报错 No module named pymysql

原因：依赖未安装。

~~~bash
pip install -r requirements.txt
~~~

### 2. 启动后页面显示数据库连接失败

排查步骤：

1. 确认 MySQL 服务已启动。
2. 确认 DB_HOST/DB_PORT/DB_USER/DB_PASSWORD/DB_NAME 正确。
3. 确认数据库脚本已执行完毕。

### 3. 社区点赞不可用

原因：未创建 post_like 表。

执行：

~~~sql
source sql/09_add_post_like.sql;
~~~

### 4. 端口冲突

项目默认跑在 5001 端口。如果你要改端口，可修改 app.py 启动参数。

## 安全说明

当前项目用于课程演示，默认账号为明文密码，无法用于生产环境：

## 后续可扩展方向

- RESTful API + 前后端分离
- Docker 一键部署
- 单元测试与集成测试
- 权限粒度增强（RBAC）
- CI/CD 自动化

## 贡献说明

欢迎提交 Issue / PR：

1. Fork 项目
2. 新建特性分支
3. 提交变更并附测试说明
4. 发起 Pull Request

## 许可证
仅用于学习与课程展示。
