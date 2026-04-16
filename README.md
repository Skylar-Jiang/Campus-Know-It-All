# 校园百事通（Campus Know-It-All）

一个基于 Flask + MySQL 的校园综合管理系统，包含活动报名、签到、物资借还、二手交易、社区互动和统计查询。

项目同时强调数据库课程能力展示：
- 事务
- 触发器
- 存储过程
- 视图

## 目录

- [项目亮点](#项目亮点)
- [技术栈](#技术栈)
- [项目结构](#项目结构)
- [快速开始](#快速开始)
- [数据库初始化](#数据库初始化)
- [默认演示账号](#默认演示账号)
- [常见问题](#常见问题)
- [安全说明](#安全说明)

## 项目亮点

1. 三角色权限：`admin` / `club` / `student`。
2. 活动全流程：发布、报名、签到、结算、删除。
3. 借还流程闭环：借用单、借用明细、库存扣减与归还回补。
4. 借用单 UID：系统自动生成 `BOR-YYYYMMDD-000001` 格式标识。
5. 社区与二手扩展：发帖评论点赞、商品发布和订单状态流转。
6. 页面风格统一为“校园百事通”极简工作台，支持吉祥物展示。

## 技术栈

- Python 3.10+
- Flask 3.0.3
- MySQL 8.0+
- PyMySQL 1.1.1
- cryptography (MySQL 8 认证所需)

## 项目结构

```text
aaSQL-project/
├─ app.py
├─ config.py
├─ requirements.txt
├─ core/
│  ├─ auth.py
│  └─ db.py
├─ routes/
│  ├─ auth_routes.py
│  ├─ home_routes.py
│  ├─ activity_routes.py
│  ├─ borrow_routes.py
│  ├─ trade_routes.py
│  ├─ community_routes.py
│  └─ stats_routes.py
├─ templates/
├─ static/
│  ├─ css/
│  └─ images/
└─ sql/
  ├─ 00_reset_database.sql
  ├─ 01_create_database.sql
  ├─ 02_create_tables.sql
  ├─ 03_insert_init_data.sql
  ├─ 04_trigger.sql
  ├─ 05_procedure.sql
  ├─ 06_view.sql
  ├─ 07_event.sql
  ├─ 08_add_trade_community.sql
  ├─ 09_add_post_like.sql
  ├─ 10_add_borrow_order_uid.sql
  ├─ 99_bootstrap_all.sql
  └─ 99_bootstrap_workbench.sql
```

## 快速开始

### 1) 克隆仓库

```bash
git clone https://github.com/Skylar-Jiang/Campus-Know-It-All
cd Campus-Know-It-All
```

### 2) 安装依赖

```bash
pip install -r requirements.txt
```

### 3) 配置数据库连接

可通过环境变量覆盖配置：

- `DB_HOST`
- `DB_PORT`
- `DB_USER`
- `DB_PASSWORD`
- `DB_NAME`
- `SECRET_KEY`

Windows PowerShell 示例：

```powershell
$env:DB_HOST="127.0.0.1"
$env:DB_PORT="3306"
$env:DB_USER="root"
$env:DB_PASSWORD="你的MySQL密码"
$env:DB_NAME="campus_activity_db"
$env:SECRET_KEY="replace-with-your-secret"
```

### 4) 启动项目

```bash
python app.py
```

访问地址：`http://127.0.0.1:5001`

## 数据库初始化

### 方案 A（推荐，MySQL Workbench）

直接执行：

- `sql/99_bootstrap_workbench.sql`

说明：该脚本为 Workbench 兼容版本，不使用 `SOURCE` 命令。

### 方案 B（MySQL 命令行）

```sql
source sql/99_bootstrap_all.sql;
```

### 方案 C（手动按顺序执行）

1. `sql/00_reset_database.sql`
2. `sql/02_create_tables.sql`
3. `sql/03_insert_init_data.sql`
4. `sql/04_trigger.sql`
5. `sql/05_procedure.sql`
6. `sql/06_view.sql`
7. `sql/07_event.sql`
8. `sql/08_add_trade_community.sql`
9. `sql/09_add_post_like.sql`

备注：
- `sql/10_add_borrow_order_uid.sql` 仅用于老库增量升级。
- 全量重建后通常不需要执行 10。

## 默认演示账号

执行 `sql/03_insert_init_data.sql` 后可使用：

- `admin1 / 123456`
- `club_music / 123456`
- `club_volunteer / 123456`
- `stu_zhang / 123456`
- `stu_li / 123456`
- `stu_wang / 123456`
- `stu_zhao / 123456`

## 吉祥物资源

- 登录页右侧与登录后右下角会显示吉祥物。
- 自定义图片路径：`static/images/mascot.png`
- 若未提供 PNG，系统会自动回退到内置 `static/images/mascot.svg`。

## 常见问题

### 1) 登录时报错：`cryptography package is required ...`

安装依赖：

```bash
pip install -r requirements.txt
```

并确认安装在“运行 Flask 的同一环境”里。

## 安全说明

当前仓库用于课程演示，默认账号为明文密码。生产环境请务必改造：

1. 密码哈希存储（如 bcrypt）
2. 关闭 debug
3. 使用强随机 `SECRET_KEY`
4. 不在仓库保存真实数据库凭据

## 许可证

仅用于学习与课程展示。
