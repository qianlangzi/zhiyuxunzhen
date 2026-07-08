package com.zhiyu.config;

import com.baomidou.mybatisplus.extension.spring.MybatisSqlSessionFactoryBean;
import org.apache.ibatis.datasource.unpooled.UnpooledDataSource;
import org.apache.ibatis.session.SqlSessionFactory;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;

import javax.sql.DataSource;

/**
 * 测试专用 MyBatis 配置
 * <p>
 * 背景：@WebMvcTest 切片测试不加载 MyBatis 自动配置（无 DataSource / SqlSessionFactory），
 * 但主启动类 ZhiyuApplication 上的 @MapperScan("com.zhiyu.mapper") 仍会注册所有
 * MapperFactoryBean，导致其在 checkDaoConfig() 阶段因缺少 sqlSessionFactory 而抛出
 * "Property 'sqlSessionFactory' or 'sqlSessionTemplate' are required" 异常。
 * <p>
 * 方案：使用 MybatisSqlSessionFactoryBean 构建一个真实的 SqlSessionFactory（内含
 * MybatisConfiguration + UnpooledDataSource）。buildSqlSessionFactory() 不会连接数据库，
 * 仅构建 Configuration 对象并注册 mapper 接口，因此不需要真实数据库。
 * <p>
 * 由于集成测试中所有 Service 均被 @MockBean 替换，Mapper 代理永远不会被实际调用，
 * 因此不会触发任何 SQL 执行。
 */
@TestConfiguration
public class MyBatisTestConfig {

    @Bean
    public DataSource dataSource() {
        // 无连接池 DataSource，测试中不会真正访问数据库
        return new UnpooledDataSource();
    }

    @Bean
    public SqlSessionFactory sqlSessionFactory(DataSource dataSource) throws Exception {
        MybatisSqlSessionFactoryBean factory = new MybatisSqlSessionFactoryBean();
        factory.setDataSource(dataSource);
        return factory.getObject();
    }
}
