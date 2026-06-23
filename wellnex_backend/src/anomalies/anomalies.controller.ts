import { Controller, Post, Get, Body, Param, Patch, Query, UseGuards, Request } from '@nestjs/common';
import { AnomaliesService } from './anomalies.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

@Controller()
export class AnomaliesController {
  constructor(private readonly anomaliesService: AnomaliesService) {}

  // ============================================
  // APP FACING (USER)
  // ============================================

  @UseGuards(JwtAuthGuard)
  @Post('api/v1/anomalies/report')
  async reportAnomaly(
    @Request() req: any,
    @Body() body: { description: string; metadata?: any },
  ) {
    return this.anomaliesService.createAnomaly(
      req.user.id,
      'USER_REPORTED',
      'MEDIUM', // user reported is medium severity by default
      body.description,
      body.metadata,
    );
  }

  // ============================================
  // ADMIN FACING
  // ============================================

  @Get('api/admin/anomalies')
  async getAnomalies(
    @Query('page') page?: string,
    @Query('limit') limit?: string,
    @Query('status') status?: string,
  ) {
    const pageNum = parseInt(page || '1', 10);
    const limitNum = parseInt(limit || '20', 10);
    return this.anomaliesService.getAnomalies(pageNum, limitNum, status);
  }

  @Patch('api/admin/anomalies/:id/status')
  async updateAnomalyStatus(
    @Param('id') id: string,
    @Body('status') status: 'PENDING' | 'RESOLVED' | 'IGNORED',
  ) {
    return this.anomaliesService.updateStatus(id, status);
  }
}
